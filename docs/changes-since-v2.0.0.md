# Changes since the last GitHub push

## Baseline and scope

Audited against GitHub `origin/main` after fetching on 2026-10-13. The remote
and local `HEAD` both point to `17280ed18a0b73643c3bd6009a9846114c6fdfaf`
(`v2.0.0`), so there are no remote-only commits or local commits ahead of
GitHub. The current working tree has **80 tracked paths** changed (1,566
insertions and 1,316 deletions) and **19 new untracked files**, including this
report. Untracked files are not included in Git's normal diff statistics.

This report describes the full project changes relative to that commit. It
does not stage, commit, or push them.

## Feature and behavior changes

### Omarchy themes and wallpapers

- Replaces the old JSON theme catalog and wallpaper-derived palette generator
  with Omarchy `colors.toml` packages. Nord is the sole bundled, protected
  fallback, with four bundled backgrounds.
- Adds `dynamite-theme` management for public theme installs, updates, removal
  of one or more installed themes, palette application, and user backgrounds.
  `create <name>` interactively accepts image paths, extracts a dark palette
  with Pillow, copies the selected images, and creates a user theme package.
- Generates the runtime palette cache and managed colors for Dynamite, Fish,
  Kitty, Foot, GTK, KDE, Fuzzel, Firefox, and Steam. Theme colors come from
  `colors.toml`; wallpaper changes do not regenerate colors.
- Adds a shared theme and wallpaper catalog with accent-family metadata. The
  theme and wallpaper pickers are separate; Mod+3 opens themes and Mod+4 opens
  the active theme's wallpapers. Applying a theme selects one of its
  wallpapers when available.
- Adds local and Wallhaven wallpaper browsing, preview/revert/keep behavior,
  theme-scoped saved downloads, and slideshow/random/next/previous selection.
  User-created packages and backgrounds live under `~/Pictures/Themes/`; old
  `~/Pictures/Wallpapers/<theme>/images/` folders are migrated without
  overwriting colliding files.
- Deletes the 19 legacy JSON theme files, wallpaper palette script, terminal
  theme service, and Kitty/Foot templates.

### Shell, overlays, and system behavior

- Makes the island window hide on outputs with fullscreen windows, restores it
  after fullscreen ends, preserves OSD behavior, and holds toasts while a
  fullscreen window is active. Escape now closes an active panel even if a
  nested control has focus.
- Improves album-art fallback and framing, slider track/thumb rendering,
  charging-ring glow, weekend coloring in the calendar, and weather layout.
- Refines media-player selection when multiple players are active; reads the
  physical battery's energy/capacity and corrects percentage handling;
  unblocks Bluetooth with `rfkill` before powering on; and stabilizes the
  collapsed Wi-Fi icon.
- Adds clipboard image thumbnails, full-size previews, queued image decoding,
  cached image data, and MIME-aware image paste through `wl-copy`.
- Adds keybind descriptions inferred from Niri config, searchable shortcut
  categories, keycap display, and delayed command execution after closing the
  cheatsheet.
- Adds a Control Center tray card, mini-player card, and Night Light page. The
  layout editor previews real tile types and supports direct drag-resizing;
  existing layouts gain the tray once while still allowing its later removal.
- Expands settings with a 12/24-hour choice, theme previews, updated Control
  Center layout editing, and theme-aware appearance controls. The default
  theme changes to Nord.

### Setup, developer guidance, and docs

- Updates `install.sh` dependency and font checks, requires Python/Pillow for
  image-based theme creation, installs the `dynamite-theme` command, and
  enables the user services as before.
- Adds version-matched Niri and Quickshell documentation entry points and
  updates contributor rules for theme-manager output paths.
- Updates the build guide for Omarchy themes, split theme/wallpaper pickers,
  changed controls, and current implementation details. Some phase documents
  remain historical design/build references; this report describes the
  implementation currently in the tree.

## File-level map

| Area | Changed tracked paths | New paths |
|---|---|---|
| Shell components | `components/AlbumCircle.qml`, `components/Slider.qml`, `components/StatusCircle.qml` | — |
| Control Center | `controlcenter/ControlCenter.qml`, `controlcenter/ControlState.qml`, `controlcenter/GridLayoutModel.qml`, `controlcenter/pages/BatteryPage.qml`, `controlcenter/pages/SystemPage.qml`, `controlcenter/pages/qmldir`, `controlcenter/tiles/SliderCard.qml`, `controlcenter/tiles/ToggleCircle.qml`, `controlcenter/tiles/qmldir` | `controlcenter/pages/NightLightPage.qml`, `controlcenter/tiles/NowPlayingCard.qml`, `controlcenter/tiles/TrayCard.qml` |
| Island and panels | `island/IslandWindow.qml`, `island/panels/Calendar.qml`, `island/panels/ClipboardPanel.qml`, `island/panels/CollapsedClock.qml`, `island/panels/HoverClock.qml`, `island/panels/KeybindsPanel.qml`, `island/panels/Launcher.qml`, `island/panels/ThemePicker.qml`, `island/panels/Toast.qml`, `island/panels/WallpaperPicker.qml`, `lock/LockSurface.qml`, `shell.qml`, `state/Island.qml`, `state/Overlays.qml` | — |
| Services and data flow | `services/Battery.qml`, `services/Bluetooth.qml`, `services/Clipboard.qml`, `services/Keybinds.qml`, `services/Media.qml`, `services/Network.qml`, `services/Niri.qml`, `services/Themes.qml`, `services/Wallhaven.qml`, `services/Wallpaper.qml`, `services/kdl.js`, `services/qmldir` | `services/ClipboardImage.py`, `services/WallpaperCommand.js`, `scripts/theme_catalog.py`, `scripts/theme_manager.py` |
| Settings and design tokens | `settings/SettingsWindow.qml`, `theme/Metrics.qml`, `theme/Theme.qml`, `config/Config.qml` | — |
| Niri and setup | `niri/simple-bar.kdl`, `dev/niri-dev.kdl`, `install.sh`, `AGENTS.md` | — |
| Project documentation | `CHANGELOG.md`, `docs/README.md`, `docs/01-architecture.md`, `docs/02-design-tokens.md`, `docs/05-control-center.md`, `docs/06-overlays.md`, `docs/07-settings.md`, `docs/08-services.md`, `docs/09-phases.md`, `docs/10-extras.md` | `docs/niri/README.md`, `docs/quickshell/README.md`, `themes/README.md`, `themes/accents/neutral/README.md` |
| Theme assets and checks | 19 old `themes/*.json` files are deleted; `themes/nord.json` is replaced by an Omarchy package | `themes/nord/colors.toml`, `themes/nord/backgrounds/0-black-moon.jpg`, `themes/nord/backgrounds/1-city-view.png`, `themes/nord/backgrounds/2-night-hawks.png`, `themes/nord/backgrounds/omarchy.png`, `themes/accent-groups.json`, `tests/qml/tst_WallpaperCommand.qml` |
| Retired implementation | `dev/palette-check.py`, `scripts/palette.py`, `services/TerminalThemes.qml`, `templates/foot.ini`, `templates/kitty.conf` | — |

## Local filesystem change outside Git

The existing `~/Pictures/Wallpapers/ghost-pastel/` and
`~/Pictures/Wallpapers/nord/` folders were moved to `~/Pictures/Themes/`.
This is user data outside the repository and will not be included by `git add`.

## Review and push

The remote baseline was fetched and matched the local `HEAD`. `git diff --check`
passed after the documentation updates. No application tests were run
as part of this audit. Before pushing, review the staged diff, including the
new binary wallpaper assets:

```sh
git add -A
git diff --cached --check
git diff --cached --stat
git diff --cached
git commit -m "Document and improve Dynamite shell"
git push origin main
```

These commands stage all repository changes, create a commit, and push it to
`origin/main`; they do not include files under `~/Pictures/Themes/`.
