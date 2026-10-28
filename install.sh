#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
missing=()
for bin in qs niri awww cliphist wl-copy wl-paste wtype tlpctl brightnessctl ddcutil wlsunset pactl curl git python3; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if ((${#missing[@]})); then
    printf 'Missing dependencies: %s\n' "${missing[*]}" >&2
    printf 'Install them with your distribution package manager, then rerun this script.\n' >&2
    exit 1
fi
if ! python3 -c 'from PIL import Image' >/dev/null 2>&1; then
    echo 'Python Pillow is required to create image-based themes.' >&2
    echo 'On Arch Linux, install it with: sudo pacman -S python-pillow' >&2
    exit 1
fi
if ! command -v fc-list >/dev/null 2>&1; then
    echo 'Fontconfig is required to check installed fonts (fc-list was not found).' >&2
    echo 'On Arch Linux, install it with: sudo pacman -S fontconfig' >&2
    exit 1
fi
font_families="$(fc-list : family)"
if ! grep -Eiq '(^|,)[[:space:]]*Inter([[:space:]]|,|$)' <<< "$font_families"; then
    echo 'Inter font is missing.' >&2
    echo 'On Arch Linux, install it with: sudo pacman -S inter-font' >&2
    exit 1
fi
if ! grep -Eiq 'Material Symbols Rounded' <<< "$font_families"; then
    echo 'Material Symbols Rounded font is missing.' >&2
    echo 'Install the Material Symbols Rounded font, then rerun this script.' >&2
    exit 1
fi
mkdir -p "$HOME/.config/quickshell" "$HOME/.config/systemd/user" "$HOME/.local/bin"
ln -sfn "$ROOT" "$HOME/.config/quickshell/simple-bar"
ln -sfn "$ROOT/scripts/theme_manager.py" "$HOME/.local/bin/dynamite-theme"
install -m 0644 "$ROOT/systemd/"*.service "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable simple-bar.service awww-daemon.service
echo 'Dynamite installed and enabled. Log out and back in to start it.'
