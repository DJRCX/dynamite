#!/usr/bin/env bash
# ==============================================================================
# simple-bar installer
# https://github.com/DJRCX/simple-bar
# ==============================================================================

set -euo pipefail

# ANSI color codes
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/simple-bar"

echo -e "${BOLD}${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}${CYAN}          Simple Bar — Setup & Installer                ${NC}"
echo -e "${BOLD}${CYAN}────────────────────────────────────────────────────────${NC}"

# 1. Check Dependencies
echo -e "\n${BOLD}[1/4] Checking system dependencies...${NC}"

MISSING_DEPS=()
OPTIONAL_DEPS=()

check_dep() {
    local cmd="$1"
    local desc="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $cmd ($desc)"
    else
        echo -e "  ${RED}✗${NC} $cmd ($desc) — ${YELLOW}Missing${NC}"
        MISSING_DEPS+=("$cmd")
    fi
}

check_opt_dep() {
    local cmd="$1"
    local desc="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $cmd ($desc)"
    else
        echo -e "  ${YELLOW}!${NC} $cmd ($desc) — ${YELLOW}Optional${NC}"
        OPTIONAL_DEPS+=("$cmd")
    fi
}

check_dep "qs" "Quickshell runtime"
check_dep "python3" "Backend hardware controller"
check_dep "nmcli" "NetworkManager CLI for Wi-Fi"
check_dep "bluetoothctl" "BlueZ CLI for Bluetooth"
check_dep "wpctl" "WirePlumber audio controller"
check_dep "brightnessctl" "Backlight controller"
check_dep "cliphist" "Clipboard history manager"
check_dep "wl-copy" "Wayland clipboard utilities (wl-clipboard)"
check_dep "wtype" "Wayland virtual keystroke simulation"
check_dep "tlpctl" "TLP profile switching (tlp-pd)"
check_dep "notify-send" "Profile-change notifications (libnotify)"

check_opt_dep "awww" "Wayland wallpaper daemon with animated transitions"
check_opt_dep "blueman-manager" "Graphical Bluetooth manager"
check_opt_dep "btop" "Terminal system & hardware monitor"

# Display package manager hints if anything is missing
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}${BOLD}Warning: Some required dependencies are missing!${NC}"
    echo -e "Install them according to your Linux distribution:\n"
    if [ -f /etc/arch-release ]; then
        echo -e "  ${BOLD}Arch Linux:${NC}"
        echo -e "    sudo pacman -S python networkmanager bluez-utils wireplumber brightnessctl cliphist wl-clipboard wtype tlp tlp-pd libnotify upower"
        echo -e "    yay -S quickshell-git blueman btop"
    elif [ -f /etc/fedora-release ]; then
        echo -e "  ${BOLD}Fedora:${NC}"
        echo -e "    sudo dnf install python3 NetworkManager bluez wireplumber brightnessctl cliphist wl-clipboard wtype blueman btop"
    elif [ -f /etc/debian_version ]; then
        echo -e "  ${BOLD}Debian / Ubuntu:${NC}"
        echo -e "    sudo apt install python3 network-manager bluez wireplumber brightnessctl cliphist wl-clipboard wtype blueman btop"
    fi
    echo ""
    read -rp "Do you wish to proceed with installation anyway? [y/N] " response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "${RED}Aborted installation.${NC}"
        exit 1
    fi
fi

# 2. Ensure Scripts are Executable
echo -e "\n${BOLD}[2/4] Setting permissions...${NC}"
chmod +x "$SCRIPT_DIR/scripts/control.py"
chmod +x "$SCRIPT_DIR/scripts/theme.py"
echo -e "  ${GREEN}✓${NC} scripts/control.py & scripts/theme.py are executable"

# 3. Link or Copy Configuration
echo -e "\n${BOLD}[3/4] Linking configuration into Quickshell config directory...${NC}"
mkdir -p "$(dirname "$TARGET_DIR")"

if [ "$SCRIPT_DIR" = "$TARGET_DIR" ]; then
    echo -e "  ${GREEN}✓${NC} Repository is already in target location: $TARGET_DIR"
else
    if [ -d "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
        BACKUP_DIR="${TARGET_DIR}.backup-$(date +%s)"
        echo -e "  ${YELLOW}!${NC} Existing directory found at $TARGET_DIR."
        echo -e "  ${YELLOW}!${NC} Backing it up to $BACKUP_DIR"
        mv "$TARGET_DIR" "$BACKUP_DIR"
    elif [ -L "$TARGET_DIR" ]; then
        rm -f "$TARGET_DIR"
    fi

    ln -sfn "$SCRIPT_DIR" "$TARGET_DIR"
    echo -e "  ${GREEN}✓${NC} Symlinked $SCRIPT_DIR → $TARGET_DIR"
fi

# 4. Install Systemd User Services
if command -v systemctl >/dev/null 2>&1; then
    echo -e "\n${BOLD}[4/5] Setting up systemd user services...${NC}"
    SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$SYSTEMD_USER_DIR"
    cp -f "$SCRIPT_DIR/systemd/simple-bar.service" "$SYSTEMD_USER_DIR/"
    cp -f "$SCRIPT_DIR/systemd/awww-daemon.service" "$SYSTEMD_USER_DIR/"
    systemctl --user daemon-reload || true
    systemctl --user enable awww-daemon.service || true
    systemctl --user enable simple-bar.service || true
    echo -e "  ${GREEN}✓${NC} Enabled awww-daemon.service & simple-bar.service"
fi

# 5. Autostart Instructions
echo -e "\n${BOLD}[5/5] Installation Complete! 🎉${NC}"
echo -e "${BOLD}${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}To start the bar right now, run:${NC}"
echo -e "  ${GREEN}systemctl --user start simple-bar.service${NC}  or  ${GREEN}qs -d -p $TARGET_DIR &${NC}"
echo -e ""
echo -e "${BOLD}Autostart:${NC}"
echo -e "  awww-daemon & simple-bar services are enabled under graphical-session.target."
echo -e "  In Niri, they start automatically on login via:"
echo -e '    spawn-at-startup "systemctl" "--user" "start" "awww-daemon.service" "simple-bar.service"'
echo -e "${BOLD}${CYAN}────────────────────────────────────────────────────────${NC}"
