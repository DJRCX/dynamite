#!/usr/bin/env bash
# Usage: run-nested.sh [start|stop|restart|status] [--windowed]
# Starts a nested Niri running Dynamite in the background and returns.
# Niri discards its children's output, so Quickshell is started through a
# wrapper that writes to /tmp/dynamite-dev.log. The nested display name is
# stored in /tmp/dynamite-display for dev/ipc.sh, dev/log.sh and dev/shot.sh.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE=/tmp/dynamite-display
PIDFILE=/tmp/dynamite-niri.pid
NIRI_LOG=/tmp/dynamite-niri.log
QS_LOG=/tmp/dynamite-dev.log
HOST_DISPLAY="${WAYLAND_DISPLAY:-}"

cmd="${1:-start}"
windowed=false
for arg in "$@"; do [[ "$arg" == "--windowed" ]] && windowed=true; done

running() { [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

stop() {
    if running; then
        kill "$(cat "$PIDFILE")" 2>/dev/null || true
        for _ in $(seq 20); do running || break; sleep 0.1; done
    fi
    rm -f "$PIDFILE" "$STATE"
}

start() {
    if running; then
        echo "already running on $(cat "$STATE" 2>/dev/null)"
        return 0
    fi
    if [[ -z "$HOST_DISPLAY" || ! -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$HOST_DISPLAY" ]]; then
        echo "WAYLAND_DISPLAY ('$HOST_DISPLAY') is not a live Wayland socket: run this from the live Niri session" >&2
        exit 1
    fi

    local cfg
    cfg="$(mktemp --suffix=.kdl)"
    sed "s#DYNAMITE_DIR#$DIR#g" "$DIR/dev/niri-dev.kdl" > "$cfg"
    : > "$QS_LOG"

    # DYNAMITE_DEV=1: don't claim session-bus names (notifications, polkit) that the live bar owns.
    DYNAMITE_DEV=1 setsid niri -c "$cfg" -- sh -c 'exec qs -p "$0" >>"$1" 2>&1' "$DIR" "$QS_LOG" \
        > "$NIRI_LOG" 2>&1 < /dev/null &
    echo $! > "$PIDFILE"

    local display=""
    for _ in $(seq 50); do
        display="$(sed -n 's/.*listening on Wayland socket: \(wayland-[0-9]*\).*/\1/p' "$NIRI_LOG" | tail -n1)"
        [[ -n "$display" ]] && break
        if ! running; then
            echo "nested niri exited; see $NIRI_LOG" >&2
            tail -n 20 "$NIRI_LOG" >&2
            grep -q NoCompositor "$NIRI_LOG" && echo "NoCompositor: the host socket exists but can't be opened. Is this running inside a sandbox (e.g. Codex without full access)?" >&2
            exit 1
        fi
        sleep 0.1
    done
    [[ -n "$display" ]] || { echo "nested niri didn't open a socket; see $NIRI_LOG" >&2; exit 1; }
    echo "$display" > "$STATE"

    # Make the nested output exactly the host output's size (1920x1080 on eDP-1)
    # so measurements and crop boxes match the reference screenshots.
    if ! $windowed; then
        local id=""
        for _ in $(seq 30); do
            id="$(WAYLAND_DISPLAY="$HOST_DISPLAY" niri msg -j windows 2>/dev/null | python3 -c '
import json, sys
ws = [w for w in json.load(sys.stdin) if w.get("app_id") == "niri"]
print(max(ws, key=lambda w: w["id"])["id"] if ws else "")')"
            [[ -n "$id" ]] && break
            sleep 0.1
        done
        if [[ -n "$id" ]]; then
            # Prefer DYNAMITE_OUTPUT, else the first host output that is exactly 1920x1080.
            local output="${DYNAMITE_OUTPUT:-}"
            if [[ -z "$output" ]]; then
                output="$(WAYLAND_DISPLAY="$HOST_DISPLAY" niri msg -j outputs | python3 -c '
import json, sys
for name, o in sorted(json.load(sys.stdin).items()):
    l = o.get("logical") or {}
    if l.get("width") == 1920 and l.get("height") == 1080:
        print(name); break')"
            fi
            [[ -n "$output" ]] && WAYLAND_DISPLAY="$HOST_DISPLAY" niri msg action move-window-to-monitor --id "$id" "$output" >/dev/null
            WAYLAND_DISPLAY="$HOST_DISPLAY" niri msg action fullscreen-window --id "$id" >/dev/null
            [[ -z "$output" ]] && echo "warning: no 1920x1080 host output; screenshots won't match the reference crop boxes" >&2
        fi
    fi

    for _ in $(seq 50); do
        grep -q "Configuration Loaded\|ERROR\|error" "$QS_LOG" 2>/dev/null && break
        sleep 0.1
    done
    echo "nested display: $display"
    echo "quickshell log: $QS_LOG   niri log: $NIRI_LOG"
    grep -E "WARN|ERROR|error|Configuration Loaded" "$QS_LOG" || true
}

case "$cmd" in
    start) start ;;
    stop) stop; echo stopped ;;
    restart) stop; start ;;
    status) running && echo "running on $(cat "$STATE")" || echo "not running" ;;
    *) echo "usage: $0 [start|stop|restart|status] [--windowed]" >&2; exit 2 ;;
esac
