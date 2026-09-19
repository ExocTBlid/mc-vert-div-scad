#!/usr/bin/env bash
#
# make-divider.sh — generate a divider STL for a given name.
#
# Usage:
#   ./make-divider.sh "Jessica Jones"
#   ./make-divider.sh "Spider Man" spider-man-custom.stl   # optional explicit output
#
# The name is injected into divider.scad's `label` variable via OpenSCAD's -D
# flag (the .scad file itself is not modified); the text is always rendered in
# UPPERCASE regardless of how the name is typed. By default the output STL is
# written into the stl/ directory, named after the input: lowercased, with
# spaces and hyphens both replaced by '_'. Hyphens are kept in the card TEXT
# (they are only normalised away in the filename). An optional second argument
# overrides the output path (used verbatim, relative to the current directory).
#
# Automatic fit: before rendering, the label's natural width is measured (via a
# fast 2D SVG projection). If it would overflow the usable card width, the card
# is rendered with fit_to_width=true so the text is squeezed to fit; short names
# that already fit are left at their natural proportions. This version of
# OpenSCAD (2021.01) has no textmetrics(), so the measurement is done here in
# the wrapper rather than inside the .scad.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAD_FILE="${SCRIPT_DIR}/divider.scad"
OUT_DIR="${SCRIPT_DIR}/stl"

# --- argument handling -----------------------------------------------------
if [[ $# -lt 1 || -z "${1:-}" ]]; then
    echo "Usage: $0 \"Name To Print\" [output.stl]" >&2
    exit 1
fi

label="$1"

# Text on the card is always uppercase; the original casing is kept only for
# deriving the (lowercase) filename slug below.
label_upper="$(printf '%s' "$label" | tr '[:lower:]' '[:upper:]')"

if [[ ! -f "$SCAD_FILE" ]]; then
    echo "Error: cannot find divider.scad at $SCAD_FILE" >&2
    exit 1
fi

if ! command -v openscad >/dev/null 2>&1; then
    echo "Error: openscad is not installed or not on PATH." >&2
    exit 1
fi

# --- derive the output filename -------------------------------------------
if [[ $# -ge 2 && -n "${2:-}" ]]; then
    output="$2"
else
    # The filename uses '_' as its only separator so that '-' is free to appear
    # in the card text without affecting names. Steps: lowercase, turn each run
    # of whitespace or hyphens into a single '_', drop anything that isn't
    # alphanumeric or '_', collapse repeated '_', and trim leading/trailing '_'.
    slug="$(printf '%s' "$label" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[[:space:]-]+/_/g' \
        | tr -cd '[:alnum:]_' \
        | sed -E 's/_+/_/g; s/^_+//; s/_+$//')"

    if [[ -z "$slug" ]]; then
        echo "Error: name '$label' produced an empty filename." >&2
        exit 1
    fi
    mkdir -p "$OUT_DIR"
    output="${OUT_DIR}/${slug}.stl"
fi

# --- automatic fit ---------------------------------------------------------
# Read the geometry values that determine the usable width and the text
# rendering, straight from divider.scad so this stays in sync with the model.
# Each helper pulls `name = <number-or-string>;` from the file.
read_scad_num() {
    # $1 = variable name; prints the numeric value or nothing.
    sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*([0-9]+(\.[0-9]+)?).*/\1/p" "$SCAD_FILE" | head -1
}
read_scad_str() {
    # $1 = variable name; prints the string value (without quotes) or nothing.
    sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" "$SCAD_FILE" | head -1
}

card_w="$(read_scad_num card_w)";                 card_w="${card_w:-75}"
text_side_margin="$(read_scad_num text_side_margin)"; text_side_margin="${text_side_margin:-4}"
text_size="$(read_scad_num text_size)";           text_size="${text_size:-8}"
scad_font="$(read_scad_str font)";                scad_font="${scad_font:-BentonSans ExtraComp Black:style=Regular}"

usable_w="$(python3 -c "print($card_w - 2*$text_side_margin)")"

# Measure the label's natural rendered width with a quick 2D SVG projection.
# (This is near-instant; it renders only the text outline, no CSG.)
fit_flag=()
measure_scad="$(mktemp --suffix=.scad)"
measure_svg="$(mktemp --suffix=.svg)"
trap 'rm -f "$measure_scad" "$measure_svg"' EXIT

# Escape any double quotes in the label for embedding in the .scad snippet.
label_escaped="${label_upper//\"/\\\"}"
printf 'text("%s", size=%s, font="%s", halign="center", valign="top");\n' \
    "$label_escaped" "$text_size" "$scad_font" > "$measure_scad"

text_w=""
if openscad -o "$measure_svg" "$measure_scad" >/dev/null 2>&1; then
    # Pull the width="NNmm" from the generated SVG.
    text_w="$(grep -oE 'width="[0-9.]+mm"' "$measure_svg" | head -1 | grep -oE '[0-9.]+')"
fi

if [[ -n "$text_w" ]]; then
    if python3 -c "import sys; sys.exit(0 if $text_w > $usable_w else 1)"; then
        echo "  (label ${text_w}mm > usable ${usable_w}mm — fitting to width)"
        fit_flag=(-D "fit_to_width=true")
    fi
else
    echo "  (warning: could not measure text width; rendering at natural size)" >&2
fi

# --- render ----------------------------------------------------------------
echo "Generating '${label_upper}' -> ${output}"
openscad -o "$output" -D "label=\"${label_upper}\"" "${fit_flag[@]}" "$SCAD_FILE"

echo "Done: ${output}"
