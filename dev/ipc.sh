#!/usr/bin/env bash
# Usage: ipc.sh <target> <function> [args...]   (or: ipc.sh show)
# qs only finds instances on the current display, so point it at the nested one.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
DISPLAY_NAME="$(cat /tmp/dynamite-display 2>/dev/null)" || { echo "nested session not running (dev/run-nested.sh)" >&2; exit 1; }
if [[ "${1:-}" == "show" ]]; then
    exec env WAYLAND_DISPLAY="$DISPLAY_NAME" qs ipc -p "$DIR" show
fi
exec env WAYLAND_DISPLAY="$DISPLAY_NAME" qs ipc -p "$DIR" call "$@"
