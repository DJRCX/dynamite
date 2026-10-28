#!/usr/bin/env bash
# Usage: shot.sh <name> [x,y wxh]   → /tmp/dynamite-<name>.png
set -euo pipefail
NAME="${1:?usage: shot.sh <name> [\"x,y wxh\"]}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/dynamite-${UID}"
DISPLAY_NAME="$(cat "$RUNTIME_DIR/display" 2>/dev/null)" || { echo "nested session not running (dev/run-nested.sh)" >&2; exit 1; }
OUT="/tmp/dynamite-${NAME}.png"
if [[ -n "${2:-}" ]]; then
    WAYLAND_DISPLAY="$DISPLAY_NAME" grim -g "$2" "$OUT"
else
    WAYLAND_DISPLAY="$DISPLAY_NAME" grim "$OUT"
fi
echo "$OUT"
