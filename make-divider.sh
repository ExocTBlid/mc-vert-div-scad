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

# --- render ----------------------------------------------------------------
echo "Generating '${label_upper}' -> ${output}"
openscad -o "$output" -D "label=\"${label_upper}\"" "$SCAD_FILE"

echo "Done: ${output}"
