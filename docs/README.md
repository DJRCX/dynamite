# Dynamite — design and historical build guide

Dynamite is a Dynamic-Island-style Quickshell shell for Niri. The implementation lives at the repository root; install and development instructions are in the top-level [`README.md`](../README.md).

This documentation began as a phased implementation specification. Its architecture, UI and service descriptions remain design references, but the staged `dynamite/` layout and phase-by-phase build instructions are historical and must not be used as the current contributor workflow. For actionable defects and improvement opportunities, see [`project-audit.md`](project-audit.md).

> Before changing the shell, inspect the current source and use the version-matched platform references in [`niri/README.md`](niri/README.md) and [`quickshell/README.md`](quickshell/README.md). Treat discrepancies between this historical spec and the code as design history, not proof of current behavior.

A dated implementation snapshot is available in [`changes-since-v2.0.0.md`](changes-since-v2.0.0.md).

## Sources of truth

| What | Where |
|---|---|
| Pixel spec + clickable prototype | Figma: <https://www.figma.com/design/e7aEzCb28W0U5texJ8du4X> (page **Screens**, press Play; page **Foundations & Components** for tokens) |
| Original screenshots (1920×1080) | `/home/djrcx/Projects/figma/Screenshots of the design/` — the file for each screen is listed in `09-phases.md` |
| Author's walkthrough (behaviour + intent) | `/home/djrcx/Projects/figma/transcript-or-walkthrough-of-the-design.txt` |
| Legacy features to rebuild | `10-extras.md` (and the legacy code itself: `../../shell.qml`, `../../scripts/`, read-only) |
| This spec | `docs/*.md` |
| Niri platform behavior and configuration | [`niri/README.md`](niri/README.md) and its linked official documentation |
| Quickshell/QML APIs and integrations | [`quickshell/README.md`](quickshell/README.md) and its version-matched official documentation |

The project spec documents Dynamite's intended behavior and design. For Niri and Quickshell syntax, API behavior, and platform semantics, use the official documentation linked from those two platform reference folders.

When the spec and a screenshot disagree, the screenshot wins for looks and the spec wins for behaviour. Numbers in this spec were measured from the screenshots at 1× scale on a 1920×1080 output.

## Historical spec reading order

1. `01-architecture.md` — directory layout, windows, state machine, IPC, dev loop.
2. `02-design-tokens.md` — colors, type, metrics, shadows, icons, config keys.
3. `03-motion.md` — the spring system (measured values, how to apply them).
4. `04-island.md` — collapsed islands, status ring, hover clock, calendar, media player.
5. `05-control-center.md` — grid, tiles, sliders, notifications, sub-pages, game mode.
6. `06-overlays.md` — launcher, power menu, OSD, toast, polkit, theme picker, lock screen.
7. `07-settings.md` — settings window and the drag-and-drop control-center editor.
8. `08-services.md` — every data source and system command.
9. `09-phases.md` — historical phase plan and acceptance checks (not current tasks).
10. `10-extras.md` — simple-bar's features, what was wrong with them, and how to rebuild them.

## Historical phases at a glance

| Phases | What |
|---|---|
| 1–12 | The Dynamite design from Figma |
| 13–17 | Extras: accent-grouped themes + wallpapers + terminal colors, Wallhaven, clipboard + cheatsheet, power profiles + caffeine + idle, system monitor + weather + window menu |
| 18 | Takeover: legacy files deleted, `dynamite/` becomes the repo root (Codex prepares, you run it) |

## Historical phase prompts

The phase table and following prompt are retained for design history only. Do not treat the phases as current implementation tasks. For current development, start from the top-level README, inspect existing code, and add tests for the behavior being changed.

A historical phase prompt:

```text
Read AGENTS.md and docs/README.md, then implement Phase 3 from
docs/09-phases.md. Follow the referenced spec sections exactly.
When done, run the phase's acceptance checks, take the screenshots it asks
for with dev/shot.sh, and list anything you could not match.
```

Phases build on each other; don't skip ahead. After each phase, open the nested session yourself, hover and click around, and compare against the Figma prototype before moving on.

## Ground rules (also in `AGENTS.md`)

- Historical Phase 18 material describes a former staged migration. The current project is implemented at the repository root; do not recreate a `dynamite/` staging directory or repeat the takeover.
- Never restart `simple-bar.service` — it kills every app launched from the bar. That stays true after the takeover, because Dynamite runs under the same unit.
- Every animation is a spring (`03-motion.md`). No bezier easing curves anywhere.
- No literal colors or sizes inside components — always `Theme.*`, `Metrics.*`, `Config.*`.
