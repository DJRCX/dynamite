# 03 — Motion: springs everywhere

The original shell animates with **springs, not bezier curves**. That's what makes the islands feel physical: an animation that gets interrupted (hover out halfway, open another panel mid-morph) keeps its velocity and bends toward the new target instead of restarting.

Rule: **no `Easing.*`, no `duration:` on anything that moves or resizes.** Use Qt's `SpringAnimation` with the tokens below.

## The three springs

The physical values are what the Figma prototype uses (Smart Animate → Custom spring, mass 1). The `SpringAnimation` values were **measured on this machine** (Qt 6.11): a headless sweep of `spring`/`damping` pairs, compared against the analytic damped-oscillator curve, picking the lowest RMS error averaged over several runs. All three land within about 1% RMS of the analytic curve, with matching overshoot. Single runs vary by a few percent because Qt advances animations in ~16 ms steps, so don't chase the second decimal.

| Token | Physical (mass 1) | Damping ratio ζ | Overshoot | Settles (2%) | Qt `SpringAnimation` | Use for |
|---|---|---|---|---|---|---|
| `island` | stiffness 380, damping 26 | 0.67 | ≈ 6% | ≈ 0.31 s | `spring: 5.25, damping: 0.35` | island x/y/width/height/radius, side circles sliding out, album/status expand |
| `panel` | stiffness 520, damping 40 | 0.88 | ≈ 0.3% | ≈ 0.20 s | `spring: 6.5, damping: 0.50` | content inside an open island: sub-page height, launcher result count, CC editor tiles, toggles, sliders, content opacity |
| `fade` | stiffness 170, damping 26 | 1.00 | 0 | ≈ 0.45 s | `spring: 2.5, damping: 0.375` | lock screen in/out, wallpaper/theme crossfades |

These are a reconstruction: the screenshots don't reveal the original's physics, so the values were chosen to look like the iPhone Dynamic Island (slight overshoot on the island, crisp settle inside). They are exposed in Settings → Motion so they can be tuned live.

## `theme/Motion.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell
import qs.config

Singleton {
    readonly property bool reduced: Config.motion.reduceMotion

    readonly property QtObject island: QtObject {
        readonly property real spring:  Config.motion.islandSpring   // 5.25
        readonly property real damping: Config.motion.islandDamping  // 0.35
    }
    readonly property QtObject panel: QtObject {
        readonly property real spring:  Config.motion.panelSpring    // 6.5
        readonly property real damping: Config.motion.panelDamping   // 0.50
    }
    readonly property QtObject fade: QtObject {
        readonly property real spring:  Config.motion.fadeSpring     // 2.5
        readonly property real damping: Config.motion.fadeDamping    // 0.375
    }
}
```

Add a reusable animation component so call sites stay one line:

```qml
// components/Spring.qml
import QtQuick
import qs.theme

SpringAnimation {
    property QtObject token: Motion.island
    spring:  Motion.reduced ? 30 : token.spring
    damping: Motion.reduced ? 1.0 : token.damping
    epsilon: 0.01
}
```

Usage:

```qml
Behavior on width  { Spring { token: Motion.island } }
Behavior on height { Spring { token: Motion.island } }
Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }
```

## How to apply it

### 1. Islands animate explicit geometry, never anchors

`Behavior` does not fire for anchor-driven changes. Every island is positioned with explicit `x`, `y`, `width`, `height`, `radius` bound to *target* values computed from `Island.mode` (`04-island.md` gives the formulas). The `Behavior` on each property does the rest.

```qml
// components/SpringRect.qml — the morphing island shape
import QtQuick
import Quickshell.Widgets
import qs.theme

ClippingRectangle {               // clips children to the rounded corners
    id: root
    property real tx; property real ty; property real tw; property real th; property real tr
    x: tx; y: ty; width: tw; height: th; radius: tr
    color: Theme.island
    Behavior on x      { Spring { token: Motion.island } }
    Behavior on y      { Spring { token: Motion.island } }
    Behavior on width  { Spring { token: Motion.island } }
    Behavior on height { Spring { token: Motion.island } }
    Behavior on radius { Spring { token: Motion.island } }
}
```

Use `ClippingRectangle` from `Quickshell.Widgets`; a plain `Rectangle { clip: true }` clips to the bounding box and content would poke out of the rounded corners mid-morph.

Overshoot means `width`/`height` briefly exceed the target. Children laid out against the island must tolerate a few extra pixels (anchor content to the top-left and give it a fixed size; don't stretch it to the island).

**Overshoot only outward.** When an island *shrinks*, its width, height and radius must not dip below the target. The `island` spring overshoots about 6% of the distance travelled, so a 514 px CC collapsing to a 33 px circle would otherwise flash a ~5 px dot before bouncing back. The real `SpringRect` springs internal `sw`/`sh`/`sr` values and renders `Math.max(sprung, target)` while the last target change was a decrease (`clampShrink`, on by default). Growing keeps the full overshoot.

**Collapsed content never scales with a panel.** The album/status circle content stays 33×33. It fades back in with `opacity` + `Motion.panel` when its panel closes, and sits at the edge the island collapses toward: top-left for status, top-right for album. Scale it down only when the island is smaller than a circle (hiding): `scale: Math.min(1, Math.min(island.width, island.height) / Metrics.circle)`. Never use `scale: island.width / 33`, because closing the CC would draw a 12× ring and a pixelated glyph.

### 2. Content crossfades inside the morph

When the island changes mode, its old content and new content are both alive for a moment:

- Each panel's content is a separate `Item` with `opacity: Island.mode === "<mode>" ? 1 : 0` and `visible: opacity > 0.01`, plus `Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }`.
- Incoming content also scales from 0.96 → 1 (`Behavior on scale` with `Motion.panel`, `transformOrigin: Item.Top`).
- Content is laid out at its **final** size from the start (fixed width/height from the spec), so it doesn't reflow while the island grows; the island's clip reveals it.

Use a `Loader` per panel with `active: opacity > 0` (or `LazyLoader`) so closed panels don't cost anything.

### 3. Colors ride on a spring too

`ColorAnimation` can't spring. For anything that changes color (toggle on/off, selected row, scale chip), animate a 0→1 progress value and mix:

```qml
property real on: checked ? 1 : 0
Behavior on on { Spring { token: Motion.panel } }
color: Theme.mix(Theme.raised, Theme.accent, on)
```

### 4. Retarget, don't restart

Never stop/start animations manually or use `States`/`Transitions` with `NumberAnimation`. Just change the target property; `SpringAnimation` keeps the current velocity. That's what makes "hover in, hover out halfway" look right.

### 5. Things that are not springs

- The battery ring's level and slider values follow the data directly (data updates aren't UI transitions). Smooth them with `Motion.panel` only when the user isn't dragging.
- Spinners and pulsing dots (Bluetooth scanning, connecting) are looping `NumberAnimation`s. That's fine; they aren't transitions.
- Brightness ramps use their own timer (`08-services.md`).

### 6. Reduced motion

`Config.motion.reduceMotion` makes every `Spring` effectively instant (stiff and critically damped). Expose it in Settings → Motion.

## Choreography per interaction

| Interaction | What moves (all `island` spring unless noted) |
|---|---|
| Hover center pill → clock | center: 96×33 @y11 r16.5 → 254×116 @y18 r31; album & status slide outward to the 18.5 px gap; collapsed time fades out, hover clock fades/scales in (`panel`). |
| Click clock → calendar | center grows to 335×277; week strip fades out, month grid fades in. |
| Click album circle → media | album island grows from 33×33 to 410×213, anchored at its **right** edge (right edge = center.x − 15), y 11 → 18; album art inside crossfades to the full player. |
| Click status circle → control center | status island grows from 33×33 to 514×514, anchored at its **top-left** (x stays, y stays 11). |
| CC → sub-page | island height springs to the page height (`island`); grid fades out, sub-page fades in (`panel`). Back reverses it. |
| Launcher typing | island height follows the result count (`panel`): 366 with 6 results, 130 with 1. |
| OSD / toast | center morphs to 280×44 / 450×67 and back; auto-dismiss timers start when the spring settles. |
| Lock | the lock surface fades in from opacity 0 (`fade`); the time/date slide down 12 px as they appear. |
| Game mode on | the three islands fade/shrink to 0 while a full-width 47 px black bar grows down from y 0 (`island`); the CC re-centers under the bar. |

## Keeping Figma and QML in sync

If you retune a spring:

1. Change `Config.motion.*` (or the defaults in `Config.qml`).
2. Convert physical ↔ Qt with the check script below, and update the custom spring in Figma's prototype interactions (Smart Animate → Custom spring) if you want the prototype to match.

`dev/spring-check.qml` (run with `QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml6 dev/spring-check.qml -- island`, or `-- 300 20` for any stiffness/damping pair): it animates a grid of `SpringAnimation` pairs (spring 1–10 × damping 0.2–0.8) and prints the three closest to the analytic curve, with their overshoot. The measured results above came from exactly this procedure: 4 rounds of 1 s each, sampled every 4 ms, averaged RMS error against `x(t) = 1 − e^(−ζω₀t)(cos ω_d t + ζω₀/ω_d · sin ω_d t)`.
