# Changelog

## 2.1.0

- Replaces the legacy JSON and wallpaper-derived palette flow with Omarchy theme packages, the `dynamite-theme` manager, and Nord as the bundled fallback.
- Adds per-theme color overrides in Settings that sync to Quickshell, Kitty, Foot, Fish, Fuzzel, KDE, Firefox, and Steam.
- Adds theme-scoped wallpaper management, online wallpaper preview and save, and a CLI flow for creating themes from local images.
- Adds an interactive multi-monitor display layout manager in Control Center and Settings with visual arrangement canvas, alignment helpers, and persistent configuration.
- Adds hardware audio card profile switching (`pactl`) to the Control Center Sound page with dry-run support.
- Redesigns Settings with live search filtering, page history navigation (back/forward), grouped slider categories with units and descriptions, and theme palette editor.
- Enhances Control Center grid with flexible tile sizing, spring-animated repositioning, Tray card, mini-player card, and Night Light controls.
- Adds blurred desktop wallpaper backdrop for Niri's overview mode (`OverviewWallpaper.qml` with `place-within-backdrop true`).
- Hardens window menu force-quit to validate PIDs and protect shared XWayland client processes.
- Hardens services and background tasks: weather request generation tracking, Wallhaven download isolation, and transactional Niri recovery in `takeover.sh`.
- Updates nested development scripts to use isolated per-user runtime paths (`$XDG_RUNTIME_DIR/dynamite-$UID`).
- Switched distributed Niri IPC bindings to `qs ipc --newest`.
- Improves fullscreen island behavior, clipboard image previews and paste, keybind search, media selection, battery and Bluetooth handling, and calendar styling.

## 2.0.0

- Dynamite replaces simple-bar: a Dynamic-Island shell for Quickshell and Niri with spring-animated islands, media player, calendar, control center, launcher, power menu, OSD, notification toasts, polkit prompt, theme picker, lock screen, settings app and game mode.
- Extras: Omarchy-format themes, wallpapers (local and Wallhaven), clipboard history, keybind cheatsheet, power profiles, caffeine, weather, system monitor and window menu.
- Omarchy-format theme packages managed with `dynamite-theme`; Nord remains as the protected fallback.
- `dev/takeover.sh` migrates an existing simple-bar install; `dev/takeover.sh rollback` undoes it.

## 1.x (simple-bar)

- The previous bar. The final version is tagged `simple-bar-v1.0.0` and kept on the `simple-bar` branch.
