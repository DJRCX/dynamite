#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
missing=()
for bin in qs niri awww cliphist wl-copy wl-paste wtype tlpctl brightnessctl ddcutil wlsunset curl; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if ((${#missing[@]})); then
    printf 'Missing dependencies: %s\n' "${missing[*]}" >&2
    printf 'Install them with your distribution package manager, then rerun this script.\n' >&2
    exit 1
fi
if ! fc-list | grep -qi 'Inter'; then echo 'Inter font is missing.' >&2; exit 1; fi
if ! fc-list | grep -qi 'Material Symbols Rounded'; then echo 'Material Symbols Rounded font is missing.' >&2; exit 1; fi
mkdir -p "$HOME/.config/quickshell" "$HOME/.config/systemd/user"
ln -sfn "$ROOT" "$HOME/.config/quickshell/simple-bar"
install -m 0644 "$ROOT/systemd/"*.service "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable simple-bar.service awww-daemon.service
echo 'Dynamite installed and enabled. Log out and back in to start it.'
