# Niri documentation reference

This folder is a navigation guide and short working summary of the official Niri documentation for changes to Dynamite. It is not a copy of the full manual. Consult the upstream page for the installed Niri release whenever an API or behavior matters.

At the time this page was reviewed (2026-10-11), this machine reports `niri 26.04`. Niri's hosted manual is rolling rather than versioned, so check the installed compositor and `niri msg --help` before relying on a page's exact syntax or a newly added field.

## Official documentation sections

The [official Niri documentation](https://niri-wm.github.io/niri/) is organized into three main areas:

- **Usage:** compositor features and integrations, including [IPC](https://niri-wm.github.io/niri/IPC.html), [layer-shell components](https://niri-wm.github.io/niri/Layer%E2%80%90Shell-Components.html), [workspaces](https://niri-wm.github.io/niri/Workspaces.html), and [fullscreen and maximize](https://niri-wm.github.io/niri/Fullscreen-and-Maximize.html).
- **Configuration:** [configuration introduction and KDL syntax](https://niri-wm.github.io/niri/Configuration%3A-Introduction.html), [input](https://niri-wm.github.io/niri/Configuration%3A-Input.html), [outputs](https://niri-wm.github.io/niri/Configuration%3A-Outputs.html), [key bindings](https://niri-wm.github.io/niri/Configuration%3A-Key-Bindings.html), [layout](https://niri-wm.github.io/niri/Configuration%3A-Layout.html), [window rules](https://niri-wm.github.io/niri/Configuration%3A-Window-Rules.html), and [layer rules](https://niri-wm.github.io/niri/Configuration%3A-Layer-Rules.html), plus switch events, named workspaces, gestures, animations, and other settings.
- **Development:** compositor design and development notes, including [developing Niri](https://niri-wm.github.io/niri/Developing-niri.html) and [documenting Niri](https://niri-wm.github.io/niri/Documenting-niri.html).

The [official Niri wiki source](https://github.com/niri-wm/niri/wiki) is also useful for browsing all pages and sections.

## Pages especially relevant to this shell

| Change area | Read first | Project files |
|---|---|---|
| Live window/workspace/output state | [IPC and event stream](https://niri-wm.github.io/niri/IPC.html) | `services/Niri.qml`, `services/Displays.qml` |
| Overview wallpaper and native recent-window switching | [Overview](https://niri-wm.github.io/niri/Overview.html), [Recent Windows](https://niri-wm.github.io/niri/Configuration%3A-Recent-Windows.html), and [Layer Rules](https://niri-wm.github.io/niri/Configuration%3A-Layer-Rules.html) | `island/OverviewWallpaper.qml`, `niri/simple-bar.kdl` |
| Per-output bar visibility and fullscreen detection | [IPC](https://niri-wm.github.io/niri/IPC.html), [fullscreen and maximize](https://niri-wm.github.io/niri/Fullscreen-and-Maximize.html), and Quickshell's [Toplevel](https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/Toplevel/) docs | `services/Niri.qml`, `island/IslandWindow.qml` |
| Output configuration | [Outputs](https://niri-wm.github.io/niri/Configuration%3A-Outputs.html) | `niri/simple-bar.kdl`, `dev/niri-dev.kdl`, `services/Displays.qml` |
| Key bindings and actions | [Key Bindings](https://niri-wm.github.io/niri/Configuration%3A-Key-Bindings.html) | `niri/simple-bar.kdl`, `dev/niri-dev.kdl`, `services/Keybinds.qml` |
| Layer-shell surface behavior | [Layer-Shell Components](https://niri-wm.github.io/niri/Layer%E2%80%90Shell-Components.html) and [Layer Rules](https://niri-wm.github.io/niri/Configuration%3A-Layer-Rules.html) | `island/IslandWindow.qml`, other panel windows under `island/` |

## Working notes

- Niri's IPC guide says the JSON event stream sends a complete initial state and then updates. Prefer that stream for continuously maintained compositor state instead of polling, and handle updates defensively because changes are not always atomic.
- Prefer `niri msg --json` for scripts and state parsing. The human-readable output is explicitly not a stable scripting interface. Handle unknown JSON fields or variants where reasonable.
- Niri distinguishes fullscreen from maximized columns, maximized-to-edges, and windowed fullscreen. Do not infer fullscreen from a window's dimensions or from the focused window alone when visibility must be decided separately per output.
- Niri configuration is KDL and live reloads. Read the relevant section page for the exact syntax; do not copy a setting from an unrelated Niri version or a community config without checking it against upstream docs.

## Version and source record

- Installed Niri when reviewed: `26.04 (8ed0da4)`.
- Official docs: [niri-wm.github.io/niri](https://niri-wm.github.io/niri/), accessed 2026-10-11.
- This index summarizes the relevant official documentation; it does not vendor upstream content.
