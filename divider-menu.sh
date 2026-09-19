#!/usr/bin/env bash
#
# divider-menu.sh — interactive front-end for make-divider.sh.
#
# Two modes:
#
# Interactive (run in a terminal) — a menu lets you either:
#   1) Choose from a list  — pick one of the names/*.txt files (heroes,
#      villains, encounters, ...), then select one, several, or all entries.
#   2) Enter manually      — type any name(s) yourself.
#
# Piped / non-interactive (stdin is not a terminal) — reads names from stdin,
# one per line, and generates a divider for each. Blank lines and lines that
# start with '#' are ignored, so you can pipe a custom list:
#   cat my-list.txt | ./divider-menu.sh
#   printf 'Thor\nLoki\n' | ./divider-menu.sh
#   ./divider-menu.sh < names/heroes.txt
#
# Each selected name is handed to make-divider.sh, which renders the STL into
# stl/ using the shared naming rules.
#
# Selection syntax when choosing from a list (interactive mode):
#   1 3 5        individual items (space or comma separated)
#   2-6          an inclusive range
#   1 4-6 9      any mix of the above
#   all          every item in the list
#
# Usage:
#   ./divider-menu.sh              # interactive menu
#   ./divider-menu.sh < list.txt   # generate one divider per line of list.txt
#
# Requirements: make-divider.sh (same directory), the names/ lists (optional;
# generate them with fetch-names.sh), openscad.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAKE_DIVIDER="${SCRIPT_DIR}/make-divider.sh"
NAMES_DIR="${SCRIPT_DIR}/names"

# --- prerequisites ---------------------------------------------------------
if [[ ! -x "$MAKE_DIVIDER" ]]; then
    if [[ -f "$MAKE_DIVIDER" ]]; then
        chmod +x "$MAKE_DIVIDER" 2>/dev/null || true
    fi
fi
if [[ ! -f "$MAKE_DIVIDER" ]]; then
    echo "Error: cannot find make-divider.sh at $MAKE_DIVIDER" >&2
    exit 1
fi

# --- helpers ---------------------------------------------------------------

# Generate a divider for a single name, echoing a small header first.
generate_one() {
    local name="$1"
    printf '\n--- %s ---\n' "$name"
    bash "$MAKE_DIVIDER" "$name"
}

# Prompt with a message and read a line into the named variable.
# Usage: prompt_line "Question: " varname
prompt_line() {
    local msg="$1" __var="$2" __reply=""
    read -r -p "$msg" __reply || true
    printf -v "$__var" '%s' "$__reply"
}

# Parse a selection string ("1 3 5", "2-6", "all") against a count of items.
# Prints the chosen 1-based indices, one per line, de-duplicated and in order.
# Returns non-zero if the selection is empty or invalid.
parse_selection() {
    local sel="$1" count="$2"
    local -a chosen=()

    # Normalise commas to spaces so both separators work.
    sel="${sel//,/ }"

    if [[ "$(printf '%s' "$sel" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" == "all" ]]; then
        local i
        for ((i = 1; i <= count; i++)); do chosen+=("$i"); done
    else
        local token
        for token in $sel; do
            if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                local lo="${BASH_REMATCH[1]}" hi="${BASH_REMATCH[2]}"
                if (( lo < 1 || hi < 1 || lo > count || hi > count || lo > hi )); then
                    echo "  ! range out of bounds: $token" >&2
                    return 1
                fi
                local i
                for ((i = lo; i <= hi; i++)); do chosen+=("$i"); done
            elif [[ "$token" =~ ^[0-9]+$ ]]; then
                if (( token < 1 || token > count )); then
                    echo "  ! out of range: $token" >&2
                    return 1
                fi
                chosen+=("$token")
            else
                echo "  ! not a number or range: $token" >&2
                return 1
            fi
        done
    fi

    if (( ${#chosen[@]} == 0 )); then
        return 1
    fi

    # De-duplicate while preserving order.
    local -A seen=()
    local idx
    for idx in "${chosen[@]}"; do
        if [[ -z "${seen[$idx]:-}" ]]; then
            seen[$idx]=1
            echo "$idx"
        fi
    done
}

# --- piped / non-interactive flow ------------------------------------------
# Read names from stdin, one per line. Blank lines and lines beginning with '#'
# (comments) are skipped. Leading/trailing whitespace is trimmed.
run_stdin() {
    local line name count=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Trim leading/trailing whitespace.
        name="${line#"${line%%[![:space:]]*}"}"
        name="${name%"${name##*[![:space:]]}"}"
        # Skip blanks and comments.
        [[ -z "$name" ]] && continue
        [[ "$name" == \#* ]] && continue
        generate_one "$name"
        ((count++))
    done

    if (( count == 0 )); then
        echo "No names read from stdin." >&2
        return 1
    fi
    echo
    echo "Generated ${count} divider(s) from stdin."
}

# --- manual entry flow -----------------------------------------------------
run_manual() {
    local name
    while true; do
        prompt_line $'\nEnter a name (blank to finish): ' name
        # Trim leading/trailing whitespace.
        name="${name#"${name%%[![:space:]]*}"}"
        name="${name%"${name##*[![:space:]]}"}"
        [[ -z "$name" ]] && break
        generate_one "$name"
    done
}

# --- list selection flow ---------------------------------------------------
run_from_list() {
    # Collect available list files.
    local -a files=()
    if [[ -d "$NAMES_DIR" ]]; then
        local f
        while IFS= read -r f; do files+=("$f"); done \
            < <(find "$NAMES_DIR" -maxdepth 1 -type f -name '*.txt' | sort)
    fi

    if (( ${#files[@]} == 0 )); then
        echo "No name lists found in $NAMES_DIR." >&2
        echo "Run ./fetch-names.sh first to generate them." >&2
        return 1
    fi

    # Pick a list.
    echo
    echo "Available lists:"
    local i
    for i in "${!files[@]}"; do
        local base count
        base="$(basename "${files[$i]}" .txt)"
        count="$(grep -c '' "${files[$i]}" 2>/dev/null || echo 0)"
        printf "  %2d) %-14s (%s names)\n" "$((i + 1))" "$base" "$count"
    done

    local pick
    prompt_line "Choose a list number: " pick
    if ! [[ "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#files[@]} )); then
        echo "Invalid list choice." >&2
        return 1
    fi
    local list_file="${files[$((pick - 1))]}"

    # Load names from the chosen file (skip blank lines).
    local -a names=()
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        names+=("$line")
    done < "$list_file"

    if (( ${#names[@]} == 0 )); then
        echo "List '$(basename "$list_file")' is empty." >&2
        return 1
    fi

    # Show the numbered names.
    echo
    echo "$(basename "$list_file" .txt):"
    for i in "${!names[@]}"; do
        printf "  %3d) %s\n" "$((i + 1))" "${names[$i]}"
    done

    echo
    echo "Select items: numbers/ranges (e.g. '1 3 5' or '2-6'), or 'all'."
    local sel
    prompt_line "Selection: " sel

    local -a indices=()
    if ! mapfile -t indices < <(parse_selection "$sel" "${#names[@]}"); then
        echo "No valid selection made." >&2
        return 1
    fi
    if (( ${#indices[@]} == 0 )); then
        echo "No valid selection made." >&2
        return 1
    fi

    echo
    echo "Generating ${#indices[@]} divider(s)..."
    local idx
    for idx in "${indices[@]}"; do
        generate_one "${names[$((idx - 1))]}"
    done
}

# --- main menu -------------------------------------------------------------
main() {
    # If stdin is not a terminal, we're being piped a list — skip the menu and
    # generate a divider for each incoming line.
    if [[ ! -t 0 ]]; then
        run_stdin
        return
    fi

    echo "=============================="
    echo " Marvel Champions Divider Menu"
    echo "=============================="
    echo
    echo "How do you want to pick names?"
    echo "  1) Choose from a list"
    echo "  2) Enter manually"
    echo "  q) Quit"

    local choice
    prompt_line "Choice: " choice

    case "$choice" in
        1) run_from_list ;;
        2) run_manual ;;
        q | Q) echo "Bye." ; exit 0 ;;
        *) echo "Unrecognised choice: '$choice'" >&2 ; exit 1 ;;
    esac

    echo
    echo "All done."
}

main "$@"
