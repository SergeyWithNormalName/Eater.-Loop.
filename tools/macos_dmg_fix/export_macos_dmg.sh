#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
WRAP_DIR="$SCRIPT_DIR"

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
    GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
  else
    echo "Godot binary not found. Install Godot or set GODOT_BIN=/path/to/Godot." >&2
    exit 1
  fi
fi

OUTPUT_PATH="${1:-}"
if [[ -n "$OUTPUT_PATH" ]]; then
  :
else
  OUTPUT_PATH="$(awk -F= '/^export_path=/{print $2; exit}' "$PROJECT_ROOT/export_presets.cfg" | sed 's/^"//; s/"$//')"
fi

PATH="$WRAP_DIR:$PATH" "$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release "MacOS" "$OUTPUT_PATH"

echo "DMG exported to: $OUTPUT_PATH"
