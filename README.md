# Dynamite

Dynamite is a Dynamic-Island shell for Quickshell and Niri. It provides the island, media controls, calendar, control center, launcher, notifications, settings, lock screen and optional desktop utilities.

Formerly **simple-bar**. The final simple-bar version is preserved as the [`simple-bar-v1.0.0` release](https://github.com/DJRCX/dynamite/releases/tag/simple-bar-v1.0.0) and on the `simple-bar` branch.

## Installing

On a new machine, run `install.sh`. An existing simple-bar checkout was switched over with `dev/takeover.sh`, which keeps the `simple-bar.service` unit name and backs up the Niri files it edits; `dev/takeover.sh rollback` returns that checkout to simple-bar.

## Development

Run the nested shell from this directory with `dev/run-nested.sh start`, drive it with `dev/ipc.sh`, and capture it with `dev/shot.sh`. The nested session uses `DYNAMITE_DEV=1` for dry-run integrations.

## Keybinds

The Niri snippet in `niri/simple-bar.kdl` documents the Dynamite IPC bindings. Existing user bindings should be reviewed before adding it.

## Settings and data

Settings are stored in `~/.config/dynamite/settings.json`; generated themes and caches live under `~/.local/state/dynamite` and `~/.cache/dynamite`.

## Troubleshooting

Check `/tmp/dynamite-dev.log` for Quickshell errors. Use `qs ipc -p <shell-directory> show` to inspect IPC targets. Do not restart `simple-bar.service` while applications are running under its cgroup.
