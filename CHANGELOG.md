# Changelog

## Unreleased

- Replaces the legacy JSON and wallpaper-derived palette flow with Omarchy theme packages, the `dynamite-theme` manager, and Nord as the bundled fallback.
- Adds theme-scoped wallpaper management, online wallpaper preview and save, and a CLI flow for creating themes from local images.
- Updates generated app colors, theme and wallpaper pickers, setup checks, and documentation for the current theme system.
- Improves fullscreen island behavior, clipboard image previews and paste, keybind search, media selection, battery and Bluetooth handling, calendar styling, and Control Center editing; adds tray, mini-player, and Night Light controls.

## 2.0.0

- Dynamite replaces simple-bar: a Dynamic-Island shell for Quickshell and Niri with spring-animated islands, media player, calendar, control center, launcher, power menu, OSD, notification toasts, polkit prompt, theme picker, lock screen, settings app and game mode.
- Extras: Omarchy-format themes, wallpapers (local and Wallhaven), clipboard history, keybind cheatsheet, power profiles, caffeine, weather, system monitor and window menu.
- Omarchy-format theme packages managed with `dynamite-theme`; Nord remains as the protected fallback.
- `dev/takeover.sh` migrates an existing simple-bar install; `dev/takeover.sh rollback` undoes it.

## 1.x (simple-bar)

- The previous bar. The final version is tagged `simple-bar-v1.0.0` and kept on the `simple-bar` branch.
