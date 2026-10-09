# 09 — Build phases

Eighteen phases, one Codex session each:

- **1–12: the Dynamite design** (everything in Figma).
- **13–17: extras.** simple-bar's features rebuilt and improved (`10-extras.md`). No Figma frames; built from the same tokens and components.
- **18: takeover.** The legacy shell is deleted and Dynamite becomes the whole repo. Codex prepares it; you run it.

Every phase ends with the shell running cleanly in the nested session (`dev/run-nested.sh`, no `ERROR`/`WARN` lines from Dynamite's files in `/tmp/dynamite-dev.log`) and a short report of anything that doesn't match.

Screenshot references are in `/home/djrcx/Projects/figma/Screenshots of the design/`; Figma frame numbers refer to the **Screens** page.

## Visual check procedure

Every mode must be openable from IPC so it can be screenshotted without a mouse: `island open <mode>`, `cc page <name>`, `notifs debugInject …`, plus a dev-only `island preview polkit`.

```bash
dev/run-nested.sh start                # background; 1920x1080; prints WARN/ERROR lines
dev/ipc.sh island open clock           # IPC into the nested instance
sleep 0.6                                       # let the springs settle
dev/shot.sh clock
magick "/tmp/dynamite-clock.png" -crop 380x160+770+0 /tmp/a.png
magick "/home/djrcx/Projects/figma/Screenshots of the design/2026-10-08__2355-08.png" -crop 380x160+770+0 /tmp/b.png
magick compare -metric RMSE /tmp/a.png /tmp/b.png /tmp/diff.png; echo
```

The wallpaper differs, so judge the diff image by eye: the island's outline, text positions and sizes should line up. Use the crop box listed for each screen (x, y, w, h on a 1920×1080 output). `run-nested.sh` already makes the nested output 1920×1080; check with `magick identify` if in doubt.

To check a spring's motion, grab a burst of region shots right after triggering it (`for i in $(seq 8); do dev/shot.sh f$i "0,0 1920x80"; done`) and measure an edge per frame. With the `island` spring, the overshoot is about 6% of the travel.

| # | Screen | Reference file | Crop box |
|---|---|---|---|
| 01 | Desktop, collapsed | `2026-10-08__2354-42.png` | 840, 0, 240, 60 |
| 02 | Media player | `2026-10-08__2354-53.png` | 470, 0, 600, 250 |
| 03 | Hover clock | `2026-10-08__2355-08.png` | 770, 0, 380, 160 |
| 04 | Calendar | `2026-10-08__2355-18.png` | 720, 0, 480, 320 |
| 05 | Control center | `2026-10-08__2356-21.png` | 850, 0, 700, 540 |
| 06 | CC — Wi-Fi | `2026-10-08__2356-53.png` | 850, 0, 700, 540 |
| 07 | CC — Bluetooth | `2026-10-08__2357-04.png` | 850, 0, 700, 540 |
| 08 | CC — Bluetooth scanning | `2026-10-08__2357-20.png` | 850, 0, 700, 540 |
| 09 | CC — Sound | `2026-10-08__2357-34.png` | 850, 0, 700, 750 |
| 10 | CC — Display | `2026-10-08__2358-11.png` | 850, 0, 700, 600 |
| 11 | Game mode | `2026-10-08__2358-33.png` | 0, 0, 1920, 580 |
| 12 | Lock screen | `2026-10-08__2359-04.png` | full |
| 13 | Lock — password | `2026-10-08__2359-34.png` | full |
| 14 | Launcher | `2026-10-08__2359-58.png` | 630, 0, 660, 400 |
| 15 | Launcher — search | `2026-10-09__0000-17.png` | 630, 0, 660, 170 |
| 16 | Power menu | `2026-10-09__0000-39.png` | 630, 0, 660, 150 |
| 17 | Notification toast | `2026-10-09__0000-59.png` | 660, 0, 600, 100 |
| 18 | Volume OSD | `2026-10-09__0001-20.png` | 750, 0, 420, 80 |
| 19 | Polkit prompt | `2026-10-09__0002-01.png` | 680, 0, 560, 300 |
| 20 | Settings — Control Center | `2026-10-09__0002-19.png` | 300, 76, 1320, 970 |
| 21 | Settings — Bar & Island | `2026-10-09__0002-34.png` | 300, 76, 1320, 970 |
| 22 | Theme picker | `2026-10-09__0002-59.png` | 500, 0, 920, 260 |

The Wi-Fi and Bluetooth references were captured mid-animation (the panel is offset by a few pixels). Match the settled geometry in `05-control-center.md`, not the offset.

---

## Phase 1 — Scaffold, dev loop, tokens, motion

Read: `01-architecture.md`, `02-design-tokens.md`, `03-motion.md`.

Build:
- The `dynamite/` tree (empty placeholders where needed), `shell.qml` with a single test `PanelWindow`.
- `dev/niri-dev.kdl`; `dev/run-nested.sh`, `dev/ipc.sh`, `dev/shot.sh` are already provided and tested (`01-architecture.md` → Development loop); don't rewrite them.
- `theme/Theme.qml` loading `themes/horizon-mint.json`; `theme/Metrics.qml`; `theme/Motion.qml`; `components/Spring.qml`; `components/SpringRect.qml`; `components/Icon.qml`.
- `config/Config.qml` with every key and default from `02-design-tokens.md`, saving to `~/.config/dynamite/settings.json`.
- `dev/spring-check.qml` (already provided) must run and print the three fits.

Accept:
- `run-nested.sh` opens a nested Niri with Dynamite running and a clean log.
- A test `SpringRect` toggled by `island open test` visibly overshoots slightly and settles in about 0.3 s.
- Editing `~/.config/dynamite/settings.json` by hand updates the running shell, and changing a value from QML writes the file. To make this observable, bind the test rect's collapsed width to `Config.island.collapsedWidth` and add a dev-only IPC `dev.setConfig(path: string, value: string)` (e.g. `island.collapsedWidth 140`): editing the file must resize the rect (springing), and the IPC must update the file.

## Phase 2 — Island window, collapsed state, geometry engine

Read: `01-architecture.md` (windows, state machine, mask), `04-island.md` (geometry, collapsed contents).

Build: `state/Island.qml`; `island/IslandWindow.qml` with three `SpringRect`s bound to the geometry functions; `island/Scrim.qml`; input `mask`; `services/Battery.qml`, `services/Network.qml` (status only), `services/Media.qml` (active player only); `components/StatusCircle.qml`, `components/AlbumCircle.qml`, `panels/CollapsedClock.qml`; IPC `island open/close/toggle`.

Accept:
- Matches screen 01: pill 96×33 at x 912, circles at 869 and 1018, all at y 11.
- The battery ring shows the real charge, centered at 12 o'clock with the gap at the bottom.
- Clicks between and around the islands reach the windows below.
- `island open launcher` (with an empty placeholder panel 514×366) makes the center grow and the side circles slide out to 652 / 1236 with the same spring.

## Phase 3 — Hover clock and calendar

Read: `04-island.md` (hover clock, calendar), `03-motion.md` (crossfade).

Accept: matches screens 03 and 04; hover timings 80/120/350 ms; month switching animates; today highlighted; Sundays red; rapid hover in/out never snaps.

## Phase 4 — Media player

Read: `04-island.md` (media player).

Accept: matches screen 02 with a real player (Spotify or `mpv --input-ipc-server` + `playerctl`); the tint follows the theme accent; seeking works; prev/play/next work; the album island grows from its right edge.

## Phase 5 — Control center grid

Read: `05-control-center.md` (grid, layout model, items), `08-services.md` (Audio, Notifs, Bluetooth/Network status).

Build: `ControlCenter.qml`, `GridLayoutModel.qml` (data + pure placement functions), `Tile`, `ToggleCircle`, `SliderCard`, `NotificationsCard`, `components/Switch.qml`, `components/Slider.qml`, `services/Audio.qml`, `services/Notifs.qml` (+ `debugInject`), Focus (DND) and Lock toggles.

Accept: matches screen 05; the layout comes from `Config.controlCenter.items` (editing the JSON re-arranges the grid live); toggles spring between colors; the sound slider changes the real volume.

## Phase 6 — Wi-Fi, Bluetooth and Sound pages

Read: `05-control-center.md` (sub-pages), `08-services.md` (Network, Bluetooth, Audio).

Accept: matches screens 06–09; header items are on one centered line; the island height springs between 514 and 717; Bluetooth connect/disconnect shows the in-progress animation; scanning shows the pulsing dot; choosing an output device changes the default sink.

## Phase 7 — Display page, brightness ramp, night light

Read: `05-control-center.md` (Display), `08-services.md` (Displays, Brightness, Night light).

Accept: matches screen 10; dragging the slider from 10% to 90% ramps smoothly on both the laptop panel and an external DDC monitor (no visible steps); scale chips and mode list apply via `niri msg`; night light works and its temperature slider is debounced.

## Phase 8 — Launcher and power menu

Read: `06-overlays.md` (launcher, power menu), `08-services.md` (Apps, Power).

Accept: matches screens 14–16; the island height follows the result count with the `panel` spring; the selection bar slides; launched apps are spawned through Niri (check with `systemd-cgls --user-unit` or `/proc/<pid>/cgroup` that they're not under Quickshell); destructive power actions need confirmation.

## Phase 9 — OSD, toast, polkit

Read: `06-overlays.md` (OSD, toast, polkit), `01-architecture.md` (priority rules, D-Bus owners).

Accept: matches screens 17–19 (toast via `notifs debugInject`, polkit via the preview flag); OSD appears on volume keys and hides after 1.6 s; toasts queue; the polkit shake works in preview. Real polkit/notifications are verified after the takeover (Phase 18).

## Phase 10 — Lock screen

Read: `06-overlays.md` (lock screen).

Accept: matches screens 12–13 in the nested session; wrong password shakes; the right password unlocks with the fade spring; every output gets a surface. **Test only inside the nested session** — a broken session lock on the real session can lock you out (if that happens, switch to a TTY and `pkill -f "qs -p .*dynamite"`).

## Phase 11 — Themes, theme picker, game mode

Read: `02-design-tokens.md` (themes), `06-overlays.md` (theme picker), `05-control-center.md` (game mode).

Accept: matches screens 22 and 11; at least 8 theme JSONs (the `wallpaper` theme comes in Phase 13); applying a theme recolors everything live (islands, CC, media tint); game mode swaps the islands for the 47 px bar, changes the exclusive zone, and restores everything on exit.

## Phase 12 — Settings app and CC layout editor

Read: `07-settings.md`.

Accept: matches screens 20–21; every Bar & Island slider live-morphs the island; the Motion page's live preview uses the edited spring; the CC editor supports move, resize, right-click sizes, add, remove, Tidy, Undo, Reset and 5–9 columns, and "Doesn't fit here" springs the item back; `GridLayoutModel` functions have a headless test (`dev/grid-test.qml`).

Settings pages for the extras (Wallpaper, Clipboard, Power & Battery, Weather, System monitor) are added in Phases 13–17; leave them out of the sidebar until their phase.

---

# Extras (Phases 13–17)

These rebuild simple-bar's features (`10-extras.md`). No Figma reference exists, so each phase's report must include a screenshot of every new mode/page, plus a sentence on how it reuses existing components. Each phase also adds its settings page/rows and its config keys (`02-design-tokens.md` → extras keys), including the one-time legacy import.

## Phase 13 — Wallpapers, wallpaper theme, terminal colors

Read: `10-extras.md` §1–3, Migration.

Build: `services/Wallpaper.qml`, `island/panels/WallpaperPicker.qml` (Local tab only), `scripts/palette.py`, the `wallpaper` theme + swatches in the theme picker, `services/TerminalThemes.qml`, `templates/kitty.conf`, `templates/foot.ini`, IPC `wallpaper.*`, Settings → Wallpaper.

Accept: the acceptance lists of §1–3. In the nested session use a scratch wallpaper folder and a scratch `$HOME`-relative output for terminal files if you don't want to touch the real Kitty config (`DYNAMITE_TERMINAL_DIR` override for dev is fine).

## Phase 14 — Wallhaven

Read: `10-extras.md` §4.

Build: `services/Wallhaven.qml`, the Online tab, preview/keep/revert, settings rows (API key, purity, fit screen).

Accept: the acceptance list of §4.

## Phase 15 — Clipboard history and keybinding cheatsheet

Read: `10-extras.md` §5–6, `01-architecture.md` (compatibility IPC targets).

Build: `services/Clipboard.qml`, `ClipboardPanel.qml`, `services/kdl.js` + `dev/kdl-test.qml`, `services/Keybinds.qml`, `KeybindsPanel.qml`, the `clipboard` and `cheatsheet` compat targets, Settings → Clipboard.

Accept: the acceptance lists of §5–6. The nested session shares the real clipboard and the real `cliphist` database: read freely, but only delete entries you created for the test.

## Phase 16 — Power profiles, battery page, caffeine, idle

Read: `10-extras.md` §7–8.

Build: `services/PowerProfile.qml`, `services/Idle.qml`, CC controls `power` and `caffeine` (+ add-chips in the editor), `pages/BatteryPage.qml`, IPC `power.*`, `caffeine.*`, dev-only `power.debugBattery`, copy `../tlp/simple-bar.conf` to `dynamite/tlp/`, Settings → Power & Battery.

Accept: the acceptance lists of §7–8. **Don't change the real TLP profile repeatedly while testing**: put `PowerProfile` in a dry-run mode for the nested session (log the `tlpctl` call instead of running it) and run one real switch at the end.

## Phase 17 — System monitor, weather, window menu, launcher parity

Read: `10-extras.md` §9–11 and "Launcher parity".

Build: `services/SysStats.qml`, CC control `system`, `pages/SystemPage.qml`, `services/Weather.qml` + calendar strip (+ optional hover clock / lock screen), `WindowMenu.qml`, the game-bar app title, launcher parity items and prefixes, Settings → Weather and → System monitor.

Accept: the acceptance lists of §9–11; the launcher finds a Flatpak app and a `~/Desktop` launcher; `;`, `?` and `!` prefixes switch modes.

---

# Phase 18 — Takeover: Dynamite replaces simple-bar (prepared by Codex, run by you)

Goal: the repo **is** Dynamite. The legacy bar's files are deleted, the contents of `dynamite/` move to the repo root, `simple-bar.service` (same name, same `~/.config/quickshell/simple-bar` path) runs Dynamite, and nothing is lost if you need to go back.

Why it's done this way: `~/.config/quickshell/simple-bar` is a symlink to this repo, and the running bar hot-reloads from it. Shuffling files one by one in the live tree would make the running bar reload into half-moved states. Instead, the whole new tree is built as **one commit on a separate branch**, then fast-forwarded in one step.

## What Codex writes (inside `dynamite/`)

1. **Final repo files:** `README.md` (Dynamite's features, install, keybinds, troubleshooting), `AGENTS.md` (rules for future work on Dynamite: never restart the service, springs only, tokens only, no push, keep files small), `install.sh` (fresh installs: dependency check incl. `awww`, `cliphist`, `wl-clipboard`, `wtype`, `tlp`/`tlp-pd`, `brightnessctl`, `ddcutil`, `wlsunset`, `python-pillow`, `curl`, Inter and Material Symbols Rounded via `fc-list`; symlink the repo to `~/.config/quickshell/simple-bar`; install and **enable** the units; never start/stop/restart), `.gitignore`, `CHANGELOG.md` (starts fresh at Dynamite 1.0).
2. **`systemd/simple-bar.service`**: same as the legacy unit (`ExecStart=/usr/bin/qs -p %h/.config/quickshell/simple-bar`, `Wants`/`After` `awww-daemon.service`). **`systemd/awww-daemon.service`**: the daemon only, no `ExecStartPost` (Dynamite restores wallpapers itself).
3. **`niri/simple-bar.kdl`**: the binds from `01-architecture.md` → "Niri binds" (after re-checking for conflicts) and a window rule that opens the settings window floating and centered.
4. **`takeover.sh`** with three subcommands:

   **`prepare`** (safe; changes nothing outside git):
   - Refuse to run with uncommitted changes; print `git status --short` and the command to commit them.
   - `git tag pre-dynamite` at HEAD (refuse if the tag exists, unless `--force`).
   - Create branch `takeover` in a temporary `git worktree`. In that worktree:
     - `git rm -r` the legacy files: `shell.qml`, `scripts/`, `systemd/`, `tlp/`, `install.sh`, `README.md`, `CHANGELOG.md`, `GEMINI.md`, `AGENTS.md`, `config.json`, `.gitignore`.
     - `git mv` every entry of `dynamite/` (including dotfiles) to the root, then remove the empty `dynamite/`. Move `takeover.sh` to `dev/takeover.sh` (so `rollback` stays available).
     - `git mv docs/* docs/` and rewrite paths in `docs/*.md`, `README.md`, `AGENTS.md`: `docs/` → `docs/`, `dev/` → `dev/`.
     - Check: no QML/JS/shell file references `dynamite/` as a path (`rg -n "dynamite/" --glob '*.{qml,js,sh}'` finds nothing except state dirs like `~/.config/dynamite`, `~/.local/state/dynamite`, `~/.cache/dynamite`).
     - Commit: "Replace simple-bar with Dynamite".
   - Remove the worktree; print `git show --stat takeover` and the next command.

   **`apply`** (you run this; it touches your session config):
   - Preconditions: on `main`, clean tree, branch `takeover` exists and is based on the current `main` (if `main` moved since `prepare`, say so and tell the user to run `prepare --force` again), tag `pre-dynamite` exists. Show the plan and ask for confirmation. `--dry-run` prints every step without doing it.
   - `git merge --ff-only takeover`. The running bar hot-reloads straight into Dynamite. That's expected; apps are not affected.
   - Copy `systemd/*.service` to `~/.config/systemd/user/`, `systemctl --user daemon-reload`, `systemctl --user enable simple-bar.service awww-daemon.service`. **Never** `start`, `stop` or `restart`.
   - Check `cliphist.service` and `cliphist-images.service` are enabled; warn if not.
   - Polkit: write `Hidden=true` overrides in `~/.config/autostart/` for the polkit-gnome and polkit-mate autostart entries (copy each file name from `/etc/xdg/autostart/`), and comment out the `spawn-at-startup ".../polkit-mate-authentication-agent-1"` line in `~/.config/niri/config.d/50-startup.kdl`. Don't kill the running agents; logging out takes care of them.
   - Niri: back up every file it edits as `<file>.pre-dynamite`. In `70-binds.kdl`, remove the Mod+Alt+Left/Right bar-workspace binds and the binds that `niri/simple-bar.kdl` replaces (Mod+Alt+L swaylock, Mod+Shift+Ctrl+Q restart, brightness keys). Copy `niri/simple-bar.kdl` to `config.d/75-simple-bar.kdl` and add `include "config.d/75-simple-bar.kdl"` after the `70-binds` include. Show the diff, ask for confirmation, then run `niri validate`; if it fails, restore the backups and stop.
   - TLP: if `/etc/tlp.d/90-simple-bar.conf` differs from `tlp/simple-bar.conf`, print the `sudo install …` command (never run sudo).
   - Print the after-login checklist (below) and ask "Log out now? [y/N]"; on yes: `niri msg action quit --skip-confirmation`.

   **`rollback`**: confirm, then `git reset --hard pre-dynamite`, restore every `*.pre-dynamite` backup, delete the `Hidden=true` overrides, reinstall the legacy units from the restored tree, `daemon-reload`, and tell you to log out and back in.

## What Codex verifies (never on the real repo or session)

- `bash -n dynamite/takeover.sh dynamite/install.sh` (and `shellcheck` if installed).
- On a **copy**: `cp -a . /tmp/takeover-test && cd /tmp/takeover-test && git add -A && git commit -qm wip && ./dynamite/takeover.sh prepare`. Then check the `takeover` branch: no legacy files, no `dynamite/` directory, docs moved, paths rewritten.
- In a worktree of that branch, start the nested session from the new root (`dev/run-nested.sh`) and confirm a clean log and that the island, CC, launcher, clipboard and wallpaper picker open.
- `./dynamite/takeover.sh apply --dry-run` on the copy prints the full plan and changes nothing (compare `git status` and `~/.config` mtimes before/after).
- The planned Niri edits applied to a **temporary copy** of `~/.config/niri` pass `niri validate -c <copy>/config.kdl`.
- Codex does **not** run `prepare` in the real repo, nor `apply` or `rollback` anywhere.

## What you do

1. Commit your work (`git add -A && git commit -m "Dynamite"`). That includes the legacy edits from Oct 8, so they're preserved in history.
2. `./dynamite/takeover.sh prepare` → look at `git show --stat takeover`.
3. `./dynamite/takeover.sh apply` → review the Niri diff → confirm → log out.
4. Log back in and check:
   - `notify-send hello world` → island toast.
   - `pkexec true` → the island password prompt (not a GNOME/MATE dialog).
   - Mod+Space / Mod+V / Mod+Slash / Mod+Escape open launcher / clipboard / cheatsheet / power menu.
   - `systemctl --user status simple-bar.service` shows `qs -p …/simple-bar` running Dynamite; `pgrep -af polkit` shows only `polkitd`.
   - Then walk through the Figma prototype screen by screen, and each extra.
5. If anything is badly wrong: `./dev/takeover.sh rollback`, log out and back in, and you're on the old bar again.

Old leftovers you can delete by hand afterwards: `~/.config/quickshell/pill-bar` (an old second symlink to this repo), `~/.cache/simple-bar/`, `/tmp/cliphist-previews/`.
