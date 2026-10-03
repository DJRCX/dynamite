# 🌙 simple-bar

> A minimal, pitch-black floating status pill & interactive quick-settings panels built with [Quickshell](https://quickshell.outfoxxed.me/) for Wayland compositors ([Niri](https://github.com/YaLTeR/niri), [Hyprland](https://hyprland.org/), [Sway](https://swaywm.org/)).

---

## ✨ Features

- **🖤 Pitch-Black Aesthetic**: Pure `#000000` background with refined `#0a0a0a` cards and subtle high-contrast borders.
- **💊 Clean Pill Resting State**: Displays clock and date in a compact, floating pill.
- **🔮 Hover-Revealed Status Balls**: Moving the mouse near the bar smoothly animates out two floating quick-access balls:
  - **Left Ball**: Wi-Fi & Bluetooth connectivity.
  - **Right Ball**: Battery & system resources.
- **🏷️ Dynamic Hover Expansion**:
  - Hovering on the **Left Ball** expands it into an informative status pill showing your active Wi-Fi SSID and Bluetooth connection state.
  - Hovering on the **Right Ball** expands it into an informative status pill showing battery percentage and charging state (`󰂄 90% Charging`).
- **📶 Interactive Connectivity Panel**:
  - Full tabbed interface for **Wi-Fi** and **Bluetooth**.
  - **Wi-Fi**: Radio power toggle, rescan button, active network card with high-contrast **Disconnect** button, and scrollable available network list with one-click **Connect**.
  - **Bluetooth**: Power toggle, paired device list with connect/disconnect actions, and direct launcher button for `blueman-manager`.
  - Quick terminal shortcut to `nmtui`.
- **⚡ Battery & Device Resources Panel**:
  - Accurate battery stats: percentage, power draw (W), time remaining / time to full, and visual progress bar.
  - **Ultra-Smooth Sliders**:
    - **Volume Slider**: 1:1 cursor tracking on drag with zero lag, smooth easing on click and wheel scroll, and mute button (`wpctl`).
    - **Brightness Slider**: Backlight adjustment with smooth animations and throttled hardware commands (`brightnessctl`).
  - Real-time CPU usage, RAM usage, and system stats.
  - Quick launcher shortcut for `btop`.
- **🔊 Top-Bar Volume Scrolling**: Scroll the mouse wheel directly over the center clock pill to adjust audio volume on-the-fly with an auto-dismissing volume HUD.
- **📐 Window Exclusive Zone**: Reserves 46px at the top edge so tiled and maximized windows never overlap the bar.
- **🖱️ Outside-Click Dismissal**: Clicking outside any open panel or on any window instantly dismisses the panel back to the compact pill.

---

## 📦 Requirements & Dependencies

The theme relies on standard Linux utilities and Quickshell:

| Package | Purpose |
|---|---|
| **quickshell** (`qs`) | Modern Qt/QML shell environment for Wayland |
| **python3** | Lightweight asynchronous hardware query script |
| **wireplumber** (`wpctl`) | Audio volume & mute control |
| **brightnessctl** | Display backlight control |
| **networkmanager** (`nmcli`) | Wi-Fi scanning, connection, and power control |
| **bluez** (`bluetoothctl`) | Bluetooth device pairing and connection management |
| **Nerd Fonts** | System font with icons (e.g. JetBrains Mono Nerd Font) |
| **blueman** *(optional)* | Graphical Bluetooth manager (`blueman-manager`) |
| **btop** *(optional)* | Terminal hardware resource monitor |

---

## 🚀 Installation

Clone the repository and run the setup script:

```bash
git clone https://github.com/DJRCX/simple-bar.git
cd simple-bar
./install.sh
```

The installer verifies your dependencies, ensures execution permissions, and automatically symlinks the configuration to `~/.config/quickshell/simple-bar`.

### Testing / Starting Manually

```bash
qs -d -p ~/.config/quickshell/simple-bar
```

---

## 🖥️ Autostart Configuration

Add the launch command to your compositor's configuration file:

### Niri (`~/.config/niri/config.kdl`)
```kdl
spawn-at-startup "qs" "-d" "-p" "~/.config/quickshell/simple-bar"
```

### Hyprland (`~/.config/hypr/hyprland.conf`)
```ini
exec-once = qs -d -p ~/.config/quickshell/simple-bar
```

### Sway (`~/.config/sway/config`)
```ini
exec qs -d -p ~/.config/quickshell/simple-bar
```

---

## 🛠️ Architecture & Documentation

```
simple-bar/
├── shell.qml          # Declarative Quickshell interface (Bar, Balls, Panels, Sliders)
├── config.json        # Persistent bar settings (top/bottom position)
├── scripts/
│   └── control.py     # Asynchronous hardware bridge (nmcli, bluetoothctl, wpctl, etc.)
├── CHANGELOG.md       # Comprehensive log of features, bugs, and fixes
├── install.sh         # Cross-distro installer and dependency checker
└── .gitignore
```

For full details on recent fixes, features, and debugging history, refer to [CHANGELOG.md](CHANGELOG.md).

### Making Future Changes
Since the configuration is symlinked to `~/.config/quickshell/simple-bar`, any edits made in your local repository are immediately active:

1. Edit [`shell.qml`](shell.qml) or [`scripts/control.py`](scripts/control.py).
2. Reload quickshell:
   ```bash
   killall qs && qs -d -p ~/.config/quickshell/simple-bar
   ```
3. Commit and push your changes to GitHub:
   ```bash
   git add .
   git commit -m "feat: your new feature"
   git push
   ```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
