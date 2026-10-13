# Dynamite contributor rules

- Never restart or stop `simple-bar.service`; Quickshell live reloads QML.
- Every animated value uses a spring from `theme/Motion.qml`.
- Read colors, design sizes and user-configurable values from `Theme`, `Metrics` and `Config`.
- Do not push changes. Commit only when asked.
- Keep the shell self-contained. The one-time config import is the only legacy-file read.
- `scripts/theme_manager.py` may write user config only to its documented package, background, palette-cache, selection-state, and app-output paths in `themes/README.md`, including user themes and backgrounds under `~/Pictures/Themes/<slug>/`. Do not add other external config writers.
- Use `DYNAMITE_DEV=1` inside the nested session. Hardware integrations must be dry-run there.
- Use argv arrays for every process; do not construct shell command strings.
- Stop the nested session after development work.

## Platform documentation

- Before changing Niri configuration, IPC handling, outputs, fullscreen/window state, layer-shell behavior, workspaces, or bindings, read `docs/niri/README.md` and the linked official Niri documentation for the installed Niri version.
- Before changing Quickshell/QML APIs, windows, Wayland integration, processes, or Quickshell services, read `docs/quickshell/README.md` and the linked official documentation matching the installed Quickshell version (`qs --version`). Do not assume an API exists based on an older config or a different Quickshell release.
- Treat these local pages as navigation notes, not replacements for upstream documentation. If behavior or API details are unclear, consult the official page and the installed runtime's help/version output before implementing a change.
