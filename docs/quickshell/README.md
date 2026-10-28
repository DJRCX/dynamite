# Quickshell documentation reference

This folder is a navigation guide and short working summary of Quickshell's official documentation as it applies to Dynamite. It is not a copy of the full manual. Quickshell APIs evolve, so use the docs version that matches the installed runtime.

At the time this page was reviewed (2026-10-12), `qs --version` reports **Quickshell 0.3.2**. The links below are pinned to that release. If the installed version changes, switch to its matching documentation before changing APIs.

## Official documentation sections

- [Usage Guide](https://quickshell.org/docs/v0.3.2/guide/): start with the [guided introduction](https://quickshell.org/docs/v0.3.2/guide/introduction/), [QML language overview](https://quickshell.org/docs/v0.3.2/guide/qml-language/), and [item size and position](https://quickshell.org/docs/v0.3.2/guide/size-position/).
- [Type Definitions](https://quickshell.org/docs/v0.3.2/types/): API reference organized by module. The docs advise using these type pages for Quickshell features and the QtQuick type index for visual elements. The [official examples](https://git.outfoxxed.me/quickshell/quickshell-examples) provide examples, but check the version-specific API because older configs can be out of date.
- [Changelog](https://quickshell.org/changelog/) for release changes.

## Modules used by this project

The imports below were found in project QML on 2026-10-11. Follow each module link to the official 0.3.2 reference; use the module page to find the exact type used by a change.

| Module | Main project uses | Official reference |
|---|---|---|
| `Quickshell` | Shell root, `PanelWindow`, IPC handlers, singletons, app launch | [Core types](https://quickshell.org/docs/v0.3.2/types/Quickshell/) |
| `Quickshell.Io` | Process execution and output parsing | [I/O types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/) and [Process](https://quickshell.org/docs/v0.3.2/types/Quickshell.Io/Process/) |
| `Quickshell.Wayland` | Window/toplevel metadata and Wayland layer-shell behavior | [Wayland types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/), [ToplevelManager](https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/ToplevelManager/), and [Toplevel](https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/Toplevel/) |
| `Quickshell.Bluetooth` | Bluetooth adapter and device state | [Bluetooth types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Bluetooth/) |
| `Quickshell.Networking` | Network devices and connections | [Networking types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Networking/) |
| `Quickshell.Services.Mpris` | Media players and track metadata | [MPRIS types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Mpris/) |
| `Quickshell.Services.Notifications` | Notification daemon integration | [Notification types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Notifications/) |
| `Quickshell.Services.Pam` | PAM authentication | [PAM types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pam/) |
| `Quickshell.Services.Pipewire` | Audio devices and volume | [Pipewire types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/) |
| `Quickshell.Services.Polkit` | Authentication agent prompts | [Polkit types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Polkit/) |
| `Quickshell.Services.SystemTray` | Background app tray items and menus | [System tray types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.SystemTray/) |
| `Quickshell.Services.UPower` | Battery devices and charge state | [UPower types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.UPower/) |
| `Quickshell.Widgets` | Bundled UI widgets | [Widget types](https://quickshell.org/docs/v0.3.2/types/Quickshell.Widgets/) |

Qt modules also used in this project: `QtQuick`, `QtQuick.Layouts`, `QtQuick.Effects`, and `QtQuick.Shapes`. For those APIs, use the Qt documentation for the Qt version installed with Quickshell.

## Project crosswalk

- Shell root and screen-specific surfaces: `shell.qml`, `island/IslandWindow.qml`, `settings/SettingsWindow.qml`, and `lock/`.
- Quickshell service integrations: `services/` (for example `Media.qml`, `Niri.qml`, `Battery.qml`, `Bluetooth.qml`, `Network.qml`, `Audio.qml`, and `Notifs.qml`).
- Reusable UI and widgets: `components/`, `controlcenter/`, and `island/panels/`.

## Working notes

- `PanelWindow` is a core `Quickshell` type. Read its docs for screen assignment, anchors, margins, focus, and exclusion behavior when changing shell surfaces.
- `ToplevelManager` exposes windows reported by the compositor. `Toplevel.screens` reports which screens a window is visible on, but the docs warn that some compositors only report one screen even when a window is visible on several. Treat this as a platform capability and verify the behavior provided by Niri before designing per-output decisions around it.
- `Process.command` is an argument list and does not invoke a shell. Keep executable and arguments as separate entries; consult the `Process` docs before changing process lifecycle, output streams, or detached execution.
- Prefer the API docs and version-matched official examples over snippets from older shell configs. Check the release changelog when an API seems missing or behaves differently.

## Version and source record

- Installed Quickshell when reviewed: `0.3.2` (Arch Linux package). Confirm with `qs --version` before version-sensitive changes.
- Official docs: [quickshell.org/docs/v0.3.2](https://quickshell.org/docs/v0.3.2/), accessed 2026-10-12.
- This index summarizes the relevant official documentation; it does not vendor upstream content.
