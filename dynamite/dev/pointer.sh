#!/usr/bin/env bash
# Usage: pointer.sh <steps...>   e.g. pointer.sh m 750 27 s 200 c
# Drives a virtual pointer inside the nested session only (see dev/vpointer/vpointer.c for steps).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DIR/vpointer"
BIN="${XDG_CACHE_HOME:-$HOME/.cache}/dynamite-dev/vpointer"
DISPLAY_NAME="$(cat /tmp/dynamite-display 2>/dev/null)" || { echo "nested session not running (dev/run-nested.sh)" >&2; exit 1; }

if [[ ! -x "$BIN" || "$SRC/vpointer.c" -nt "$BIN" ]]; then
    build="$(dirname "$BIN")"
    mkdir -p "$build"
    wayland-scanner client-header "$SRC/wlr-virtual-pointer-unstable-v1.xml" "$build/wlr-virtual-pointer-unstable-v1-client-protocol.h"
    wayland-scanner private-code "$SRC/wlr-virtual-pointer-unstable-v1.xml" "$build/wlr-virtual-pointer-unstable-v1-protocol.c"
    gcc -O2 -Wall -I"$build" -o "$BIN" "$SRC/vpointer.c" "$build/wlr-virtual-pointer-unstable-v1-protocol.c" -lwayland-client
fi

nested_socket="$(ls "$XDG_RUNTIME_DIR"/niri."$DISPLAY_NAME".*.sock 2>/dev/null | head -n1)"
size="$(NIRI_SOCKET="$nested_socket" niri msg -j focused-output 2>/dev/null \
    | python3 -c 'import json,sys; l=json.load(sys.stdin)["logical"]; print("%dx%d" % (l["width"], l["height"]))' 2>/dev/null || echo 1920x1080)"
WAYLAND_DISPLAY="$DISPLAY_NAME" VPOINTER_SIZE="$size" exec "$BIN" "$@"
