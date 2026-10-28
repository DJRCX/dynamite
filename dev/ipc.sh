#!/usr/bin/env bash
# Usage: ipc.sh <target> <function> [args...]   (or: ipc.sh show)
# qs only finds instances on the current display, so point it at the nested one.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/dynamite-${UID}"
DISPLAY_NAME="$(cat "$RUNTIME_DIR/display" 2>/dev/null)" || { echo "nested session not running (dev/run-nested.sh)" >&2; exit 1; }
if [[ "${1:-}" == "show" ]]; then
    exec env WAYLAND_DISPLAY="$DISPLAY_NAME" qs ipc -p "$DIR" show
fi
exec env WAYLAND_DISPLAY="$DISPLAY_NAME" qs ipc -p "$DIR" call "$@"
