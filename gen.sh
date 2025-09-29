#!/usr/bin/env bash
# gen.sh — write files from CUE 'files' map (Unix)
set -euo pipefail

TMP="$(mktemp)"
cue export generate.cue -e files > "$TMP"

# Use jq if available for robust parsing; fallback to python
if command -v jq >/dev/null 2>&1; then
  mapfile -t KEYS < <(jq -r 'keys[]' "$TMP")
  for k in "${KEYS[@]}"; do
    content="$(jq -r --arg k "$k" '.[$k]' "$TMP")"
    dir="$(dirname "$k")"
    [ "$dir" != "." ] && mkdir -p "$dir"
    printf "%s" "$content" > "$k"
    echo "wrote $k"
  done
else
  python3 - "$TMP" << 'PY'
import json, os, sys, pathlib
data = json.load(open(sys.argv[1], 'r', encoding='utf-8'))
for path, content in data.items():
    d = os.path.dirname(path)
    if d and d != '.': pathlib.Path(d).mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content or '')
    print('wrote', path)
PY
fi
