# Dynamite — build guide

Dynamite is a Dynamic-Island style Quickshell shell for Niri: three black "islands" at the top of the screen (album art circle, clock pill, status circle) that morph with spring physics into a media player, clock, calendar, control center, launcher, power menu, OSD, notification toast, polkit prompt and theme picker. It also has a lock screen, a settings app and a game-mode bar.

**Dynamite fully replaces simple-bar.** It is built in `dynamite/` while the legacy bar keeps running. Then simple-bar's own features (wallpapers, clipboard, cheatsheet, power profiles, caffeine, system monitor, weather, window menu, terminal colors, Wallhaven) are rebuilt and improved inside Dynamite. Finally the legacy files are deleted and Dynamite becomes the whole repo.

This folder is the complete spec. It is written so that a coding agent (Codex) can build the shell phase by phase without seeing the original.

## Sources of truth

| What | Where |
|---|---|
| Pixel spec + clickable prototype | Figma: <https://www.figma.com/design/e7aEzCb28W0U5texJ8du4X> (page **Screens**, press Play; page **Foundations & Components** for tokens) |
| Original screenshots (1920×1080) | `/home/djrcx/Projects/figma/Screenshots of the design/` — the file for each screen is listed in `09-phases.md` |
| Author's walkthrough (behaviour + intent) | `/home/djrcx/Projects/figma/transcript-or-walkthrough-of-the-design.txt` |
| Legacy features to rebuild | `10-extras.md` (and the legacy code itself: `../../shell.qml`, `../../scripts/`, read-only) |
| This spec | `docs/*.md` |

When the spec and a screenshot disagree, the screenshot wins for looks and the spec wins for behaviour. Numbers in this spec were measured from the screenshots at 1× scale on a 1920×1080 output.

## Read in this order

1. `01-architecture.md` — directory layout, windows, state machine, IPC, dev loop.
2. `02-design-tokens.md` — colors, type, metrics, shadows, icons, config keys.
3. `03-motion.md` — the spring system (measured values, how to apply them).
4. `04-island.md` — collapsed islands, status ring, hover clock, calendar, media player.
5. `05-control-center.md` — grid, tiles, sliders, notifications, sub-pages, game mode.
6. `06-overlays.md` — launcher, power menu, OSD, toast, polkit, theme picker, lock screen.
7. `07-settings.md` — settings window and the drag-and-drop control-center editor.
8. `08-services.md` — every data source and system command.
9. `09-phases.md` — **the build plan**: 18 phases, each with deliverables and acceptance checks.
10. `10-extras.md` — simple-bar's features, what was wrong with them, and how to rebuild them.

## Phases at a glance

| Phases | What |
|---|---|
| 1–12 | The Dynamite design from Figma |
| 13–17 | Extras: wallpapers + terminal colors, Wallhaven, clipboard + cheatsheet, power profiles + caffeine + idle, system monitor + weather + window menu |
| 18 | Takeover: legacy files deleted, `dynamite/` becomes the repo root (Codex prepares, you run it) |

## How to drive Codex with this

Run one phase per Codex session. A good prompt:

```text
Read AGENTS.md and docs/README.md, then implement Phase 3 from
docs/09-phases.md. Follow the referenced spec sections exactly.
When done, run the phase's acceptance checks, take the screenshots it asks
for with dev/shot.sh, and list anything you could not match.
```

Phases build on each other; don't skip ahead. After each phase, open the nested session yourself, hover and click around, and compare against the Figma prototype before moving on.

## Ground rules (also in `AGENTS.md`)

- The legacy files (`shell.qml`, `scripts/`, `systemd/`, `tlp/`, `install.sh`, `config.json`) stay untouched until Phase 18, which deletes them. Dynamite lives in `dynamite/` and never depends on them.
- Never restart `simple-bar.service` — it kills every app launched from the bar. That stays true after the takeover, because Dynamite runs under the same unit.
- Every animation is a spring (`03-motion.md`). No bezier easing curves anywhere.
- No literal colors or sizes inside components — always `Theme.*`, `Metrics.*`, `Config.*`.
