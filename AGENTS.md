# Agent Instructions

This repository is being converted from one Quickshell shell to another, for Niri:

- `shell.qml` + `scripts/` + `systemd/` + `tlp/` + `install.sh` + `config.json`: the **legacy** bar ("simple-bar"), still the user's daily driver. It will be **deleted** in Phase 18. Do not refactor or fix it.
- `dynamite/`: the new Dynamic-Island shell that **fully replaces** the legacy bar, built from the spec in `docs/dynamite/`. In Phase 18 its contents become the repo root.

If the task mentions Dynamite, the island, the control center, an extra (wallpapers, clipboard, cheatsheet, power, caffeine, weather, system monitor, window menu), or a phase number, start with `docs/dynamite/README.md` and follow the phase you were given.

## Critical rules

1. **Never run `systemctl --user restart simple-bar.service` (or `stop`).** The unit's cgroup owns every app launched from the bar; restarting it kills the user's browsers and editors. Quickshell live-reloads QML on save, so a restart is never needed. This applies after the takeover too: Dynamite runs under the same unit name.
2. **Never `git push`.** Commit locally only when asked.
3. **Do not edit legacy files** (`shell.qml`, `scripts/*`, `systemd/*`, `tlp/*`, `install.sh`, `config.json`). The running bar hot-reloads from this repo, so any edit there changes the user's live desktop. You may *read* them to understand the features being rebuilt.
4. **Dynamite never depends on legacy files.** Don't import, call or read them at runtime (one exception: the one-time settings import from `../config.json`). If something is needed, copy it into `dynamite/` and adapt it. Never hard-code the `dynamite/` path; use `Quickshell.shellDir` / `$(dirname "$0")`, because the folder moves to the repo root in Phase 18.
5. **Develop Dynamite inside the nested Niri session**, never by starting a second shell on the live session. Use the provided, tested scripts: `dynamite/dev/run-nested.sh start|stop|status` (runs in the background at 1920×1080), `dynamite/dev/ipc.sh <target> <fn> [args]` (plain `qs ipc` can't see the nested instance; `qs -c` doesn't work on this machine), `dynamite/dev/shot.sh <name>`. Quickshell's log is `/tmp/dynamite-dev.log`. Stop the session when you're done. If Niri fails with `NoCompositor`, you're in a sandbox without access to the Wayland socket: say so and stop; don't work around it.
6. **Every animation is a spring.** No `Easing.*` curves, no `duration:` on geometry. Use the tokens in `dynamite/theme/Motion.qml`. See `docs/dynamite/03-motion.md`.
7. **Never hard-code colors or sizes in components.** Read them from `Theme`, `Metrics` and `Config`.
8. **Phase 18 (takeover):** write and test `dynamite/takeover.sh` only on a copy of the repo. Never run `takeover.sh prepare` in the real repo, and never run `apply` or `rollback` anywhere. Never edit `~/.config/niri`, `~/.config/systemd`, `~/.config/autostart` or anything under `/etc`, and never use sudo. The user runs the takeover.
9. Don't install packages or change system configuration without asking.

## Verification

- Syntax check: `qmllint` is noisy with Quickshell types; instead run the shell nested and read its log: `dynamite/dev/run-nested.sh start` prints `ERROR`/`WARN` lines; later ones are in `/tmp/dynamite-dev.log`.
- Visual check: `dynamite/dev/shot.sh <name>` grabs the nested session; compare against the reference screenshot listed for the screen in `docs/dynamite/09-phases.md`. The extras (Phases 13–17) have no reference: include screenshots of every new mode in the report.
