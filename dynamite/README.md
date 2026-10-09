# Dynamite

Dynamite is a Dynamic-Island shell for Quickshell and Niri. It provides the island, media controls, calendar, control center, launcher, notifications, settings, lock screen and optional desktop utilities.

## Development

Run the nested shell from this directory with `dev/run-nested.sh start`, drive it with `dev/ipc.sh`, and capture it with `dev/shot.sh`. The nested session uses `DYNAMITE_DEV=1` for dry-run integrations.

## Keybinds

The Niri snippet in `niri/simple-bar.kdl` documents the Dynamite IPC bindings. Existing user bindings should be reviewed before adding it.

## Settings and data

Settings are stored in `~/.config/dynamite/settings.json`; generated themes and caches live under `~/.local/state/dynamite` and `~/.cache/dynamite`.

## Troubleshooting

Check `/tmp/dynamite-dev.log` for Quickshell errors. Use `qs ipc -p <shell-directory> show` to inspect IPC targets. Do not restart `simple-bar.service` while applications are running under its cgroup.
