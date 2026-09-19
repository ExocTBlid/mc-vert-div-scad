#!/usr/bin/env bash
#
# fetch-names.sh — pull Marvel Champions set names from the community data repo
# and write them to plain-text lists, one name per line, ready to feed into
# make-divider.sh.
#
# Source (single source of truth):
#   https://github.com/zzorba/marvelsdb-json-data  ->  sets.json
#
# sets.json lists every "card set" with a `card_set_type_code`. We map those to
# three divider lists:
#   heroes      <- card_set_type_code == "hero"     (playable heroes)
#   villains    <- card_set_type_code == "villain"  (villains, deduped: no I/II/III stages)
#   encounters  <- card_set_type_code == "modular"  (encounter set names, e.g. "Bomb Scare")
#
# Output: names/heroes.txt, names/villains.txt, names/encounters.txt
#   - one name per line
#   - duplicates removed
#   - sorted (case-insensitive)
#
# Usage:
#   ./fetch-names.sh                # fetch and write all three lists
#
# Requirements: curl, python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/names"

SETS_URL="https://raw.githubusercontent.com/zzorba/marvelsdb-json-data/master/sets.json"

# Map of output-file basename -> card_set_type_code in sets.json.
declare -A LISTS=(
    [heroes]="hero"
    [villains]="villain"
    [encounters]="modular"
)

# --- prerequisites ---------------------------------------------------------
for cmd in curl python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' is not installed or not on PATH." >&2
        exit 1
    fi
done

# --- fetch -----------------------------------------------------------------
tmp_json="$(mktemp)"
trap 'rm -f "$tmp_json"' EXIT

echo "Fetching sets.json ..."
if ! curl -fsSL "$SETS_URL" -o "$tmp_json"; then
    echo "Error: failed to download $SETS_URL" >&2
    exit 1
fi

# Sanity check: valid JSON array with at least one entry.
if ! python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d,list) and d else 1)' "$tmp_json"; then
    echo "Error: downloaded sets.json is empty or not the expected format." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

# --- extract each list -----------------------------------------------------
for name in "${!LISTS[@]}"; do
    type_code="${LISTS[$name]}"
    out_file="${OUT_DIR}/${name}.txt"

    # Pull unique names for this set type, sorted case-insensitively.
    python3 - "$tmp_json" "$type_code" > "$out_file" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
wanted = sys.argv[2]
names = {s["name"].strip() for s in data
         if s.get("card_set_type_code") == wanted and s.get("name", "").strip()}
for n in sorted(names, key=str.casefold):
    print(n)
PY

    count="$(wc -l < "$out_file" | tr -d ' ')"
    echo "  ${name}: ${count} names -> ${out_file}"
done

echo "Done."
