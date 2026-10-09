# 06 — Launcher, power menu, OSD, toast, polkit, theme picker, lock screen

All of these except the lock screen are **modes of the center island** (`04-island.md` gives their sizes). Content is laid out in island coordinates (0,0 = island top-left).

## Launcher (`panels/Launcher.qml`) — 514 wide

Reference `2359-58` (list) and `0000-17` (search). Figma frames 14–15.

- Search row: `search` icon 15 px `textMuted` at (17, 24); text input at (44, 23), Regular 14, placeholder "Search..." in `textMuted`, caret 2 × 16 `text`.
- Divider at y 58: 486 × 1 at x 14, `Theme.divider`.
- Results from y 71, row pitch 46, row 486 × 47, radius 10:
  - App icon 28 px at (18, 10) (`IconImage` from `DesktopEntry.icon`, via `Quickshell.iconPath(name, true)`).
  - Name at (56, 9) SemiBold 14 `text`; comment at (56, 26) Regular 10.5 `textSecondary`, elided. Apps without a comment center the name vertically (y 15).
  - **Selected row**: a 3 × 21 `accent` bar at (1, 13) and a faint `Qt.alpha(text, 0.04)` row background. The bar slides between rows with the `panel` spring (one shared bar item, not one per row).
- Height = `83 + 47 · n` for n visible results (n ≤ `Config.launcher.maxResults` = 6), so 365 with 6 and 130 with 1. With 0 results, show "No results" and use n = 1. The island height follows with the `panel` spring as you type.
- Data: `DesktopEntries.applications.values` (filter `noDisplay`). Sort by fuzzy score on name > generic name > keywords > comment, then by launch frequency (persist counts in `~/.local/state/dynamite/launch-counts.json`). With an empty query, list alphabetically (matches the screenshot: About Xfce, Advanced Network Configuration, Alacritty, auto-cpufreq…).
- Keys: ↑/↓ or Ctrl+J/K move, Enter launches, Esc closes, Tab completes. Launch with `niri msg action spawn -- …` (`01-architecture.md`), then `Island.close()`.
- Optional, ported from simple-bar: if the query parses as arithmetic, the first row is the result; Enter copies it with `wl-copy`.

## Power menu (`panels/PowerMenu.qml`) — 514 × 110

Reference `0000-39`. Figma frame 16.

- Five actions, 89 × 82, radius 16, at x = 14, 113, 212, 312, 411 and y 15: **Lock** (`lock`), **Suspend** (`bedtime`), **Log Out** (`logout`), **Reboot** (`restart_alt`), **Power Off** (`power_settings_new`).
- Each: icon 17 px centered at y 23–40, label SemiBold 11.5 centered at y 46.
- Rest state `Theme.panel` / `text`. The **highlighted** action (keyboard focus or hover) is `Theme.accent` / `onAccent`, with the color springing between tiles (spring-mixed color, `03-motion.md` §3). The screenshot has Power Off highlighted.
- ←/→ move, Enter activates, Esc closes. Opening with the keyboard highlights Lock.
- Reboot, Power Off and Log Out need a second press: the tile's label crossfades to "Confirm?" and a second Enter/click within 3 s executes.
- Commands: lock → `Lock.lock()`; suspend → lock, then `systemctl suspend`; log out → `niri msg action quit --skip-confirmation`; reboot → `systemctl reboot`; power off → `systemctl poweroff`.

## OSD (`panels/Osd.qml`) — 280 × 44, pill

Reference `0001-20`. Figma frame 18.

- Icon 15 px at x 14 (`volume_up`, `volume_off` when muted, `light_mode` for brightness).
- Track at (41, 20): 181 × 5, radius 2.5, `trackOnIsland`; fill `accent`, width springs with `panel`.
- Percentage at x 224 (right-aligned to 264), Medium 10.5 `textSecondary`.
- Triggered by `Audio` (sink volume/mute change) and `Brightness` (target change). Each change restarts a 1.6 s timer; on timeout, back to the previous mode. It never interrupts an interactive panel (`01-architecture.md` → priority rules).

## Notification toast (`panels/Toast.qml`) — 450 × 67, pill

Reference `0000-59`. Figma frame 17.

- Avatar: 36 px circle at (12, 16) in `Theme.subpage`; app icon if available, else the app name's first letter, SemiBold 13 `accent`.
- App name at (60, 11) Regular 10.5 `textSecondary`; summary at (60, 26) **Bold 13** `text`; body at (60, 43) Regular 10.5 `textSecondary`, one line, elided.
- Shown for `Config.notifications.toastSeconds` (4 s); hover pauses the timer; critical urgency stays until clicked. Click → open the CC (notifications visible). Action buttons, if the notification has actions, appear as small pills at the right.
- Queue: toasts play one after another; each new one morphs the island in place rather than collapsing in between.

## Polkit prompt (`panels/PolkitPrompt.qml`) — 430 × 266

Reference `0002-01`. Figma frame 19. The walkthrough: run `pkexec <cmd>` → the island becomes the password box.

Use `Quickshell.Services.Polkit`:

```qml
PolkitAgent {
    id: agent
    onAuthenticationRequestStarted: Island.open("polkit")
}
// agent.flow: AuthFlow — message, actionId, iconName, inputPrompt, responseVisible,
// supplementaryMessage, supplementaryIsError, isResponseRequired, isCompleted,
// isSuccessful, isCancelled, failed; submit(value), cancelAuthenticationRequest()
```

Layout:

| Element | Position | Spec |
|---|---|---|
| Lock badge | (15, 13) 30 px circle | `accent`, `lock` 13 px `onAccent` |
| Title | (56, 18) | "Authentication required", Medium 16 `text` |
| Message box | (15, 55) 400 × 73, radius 12, `Theme.panel` | `flow.message` SemiBold 13 `text`, max 2 lines, at (12, 9); `flow.actionId` Regular 10 `textSecondary` at (12, 50) |
| Label | (15, 142) | "Password" Regular 10.5 `textMuted` (or `flow.inputPrompt`) |
| Input | (15, 168) 400 × 39, radius 19.5, `Theme.island` with a 1 px `Theme.raised` border | 26 px `raised` circle with `lock` 11 px at (7, 7); text at x 48, Regular 13; placeholder "Enter your password" `textMuted`; masked unless `flow.responseVisible` |
| Cancel | (224, 220) 72 × 32, radius 16, `raised` | SemiBold 12.5 `text` |
| Authenticate | (305, 220) 110 × 32, radius 16, `accent` | SemiBold 12.5 `onAccent` |

- Enter submits (`flow.submit(text)`); Esc or Cancel → `flow.cancelAuthenticationRequest()`.
- Wrong password (`flow.failed` / `supplementaryIsError`): clear the field, show `supplementaryMessage` in `danger` under the input, and **shake** the input: set an x offset to 14 and back to 0 with the `island` spring (its overshoot produces a natural wobble).
- On success or cancel, `Island.close()`.
- The scrim does not dismiss it.

During development the agent can't register (polkit-gnome owns it; see `01-architecture.md`). Build it against a fake flow object behind `Island.open("polkit")` with a preview flag.

## Theme picker (`panels/ThemePicker.qml`) — 802 × 220

Reference `0002-59`. Figma frame 22.

- Search row: `search` 14 px at (17, 21); "Search themes..." Regular 13 at (42, 20); counter "8/19" Regular 10 `textMuted` right-aligned at x 782.
- **Carousel** at y 64 (height 106): theme cards 185 × 98 with 9 px gaps, horizontally scrolling, the selected card centered. Each card: a mini preview of the theme (its `island`/`panel` colors with an accent swatch row from `preview`), the name below (Medium 10, SemiBold for the selected one). The selected card has a 2 px `accent` outline. Cards at the edges are clipped by the island.
- "Enter to apply" Regular 9.5 `textMuted` right-aligned at y 192.
- ←/→ (or scroll) move the selection, and the carousel `contentX` springs (`panel`) to center it. Typing filters. Enter applies (`Config.appearance.theme = name`); everything recolors live with the `fade` spring on a full-screen color crossfade. Esc closes without applying.

## Lock screen (`lock/LockScreen.qml`)

Reference `2359-04` (idle) and `2359-34` (password). Figma frames 12–13.

Use `WlSessionLock { locked: Lock.locked; WlSessionLockSurface { … } }` with one surface per screen, and `PamContext { config: "login" }` (or a custom `dynamite` PAM file) for authentication.

Per surface (1920 × 1080):

- **Background**: the wallpaper, overscanned 80 px on every side, blur 48, then black at 25%.
- **Status** top-right at (1832, 12): Wi-Fi + battery icons and percentage, 72 × 20.
- **Date** "Saturday, September 12": Medium 24 `text`, centered, top at y 124.
- **Time** "0:47" (no leading zero on the hour): SemiBold 150 `text`, centered, top at y 139.
- **Avatar** 58 px circle at (931, 835), `Theme.subpage` with `person` 24 px (or `~/.face` if it exists).
- **User name** SemiBold 15 centered at y 917.
- **Idle hint** "Press Any Key to Enter Password", Regular 12 `textSecondary`, centered at y 966.
- **Password state**: any key or click crossfades the hint into a password pill (197 × 30, radius 15, `Qt.alpha(island, 0.55)`, centered at y 958) showing dots for typed characters (`fade` spring). The first key pressed counts as input.
- Enter → `pam.respond(text)`. On failure: shake the pill (same as polkit), clear it, show "Wrong password" in `danger`. On success: fade everything out (`fade` spring), then `Lock.locked = false`.
- After 10 s of inactivity in the password state, go back to the idle hint.
- Lock in: surfaces fade in with the `fade` spring; time and date slide down 12 px as they appear.

Idle locking (lock after N minutes, lock before sleep) is built in Phase 16 with Quickshell's `IdleMonitor`; see `10-extras.md` §8. Until then, lock only through IPC and the power menu.
