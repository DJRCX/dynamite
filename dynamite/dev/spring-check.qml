// Finds the Qt SpringAnimation {spring, damping} pair that best matches a physical
// spring (mass 1), averaged over several rounds. Usage:
//   QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml6 spring-check.qml -- island
//   QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen qml6 spring-check.qml -- 380 26
import QtQuick

Item {
    id: root

    readonly property var presets: ({
        island: [380, 26],
        panel:  [520, 40],
        fade:   [170, 26]
    })
    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property var kc: args.length >= 2 ? [Number(args[0]), Number(args[1])] : (presets[args[0]] || presets.island)
    readonly property real k: kc[0]
    readonly property real c: kc[1]
    readonly property int rounds: 4

    function analytic(t) {
        const w0 = Math.sqrt(k), z = c / (2 * w0)
        if (z < 1) {
            const wd = w0 * Math.sqrt(1 - z * z)
            return 1 - Math.exp(-z * w0 * t) * (Math.cos(wd * t) + (z * w0 / wd) * Math.sin(wd * t))
        }
        if (z === 1)
            return 1 - Math.exp(-w0 * t) * (1 + w0 * t)
        const r1 = -w0 * (z - Math.sqrt(z * z - 1)), r2 = -w0 * (z + Math.sqrt(z * z - 1))
        return 1 - (r2 * Math.exp(r1 * t) - r1 * Math.exp(r2 * t)) / (r2 - r1)
    }

    property var grid: []
    property var probes: []
    property var errors: ({})
    property int round: 0
    property real t0: 0

    function startRound() {
        for (const p of probes) p.o.destroy()
        probes = grid.map(([s, d]) => ({
            s, d, samples: [],
            o: Qt.createQmlObject(`import QtQuick; QtObject { property real v: 0; Behavior on v { SpringAnimation { spring: ${s}; damping: ${d}; epsilon: 0.0001 } } }`, root)
        }))
        t0 = Date.now()
        for (const p of probes) p.o.v = 1
        sampler.start()
    }

    Component.onCompleted: {
        for (let s = 1.0; s <= 10.01; s += 0.25)
            for (let d = 0.20; d <= 0.80; d += 0.025)
                grid.push([+s.toFixed(2), +d.toFixed(3)])
        startRound()
    }

    Timer {
        id: sampler
        interval: 4; repeat: true
        onTriggered: {
            const t = (Date.now() - root.t0) / 1000
            for (const p of root.probes) p.samples.push([t, p.o.v])
            if (t < 1.0) return
            stop()
            for (const p of root.probes) {
                const e = Math.sqrt(p.samples.reduce((a, [ts, v]) => a + (v - root.analytic(ts)) ** 2, 0) / p.samples.length)
                const key = `${p.s}|${p.d}`
                const prev = root.errors[key] || { e: 0, peak: 0 }
                root.errors[key] = { s: p.s, d: p.d, e: prev.e + e, peak: prev.peak + Math.max(...p.samples.map(x => x[1])) }
            }
            if (++root.round < root.rounds) { root.startRound(); return }
            const ranked = Object.values(root.errors).sort((a, b) => a.e - b.e).slice(0, 3)
            const z = root.c / (2 * Math.sqrt(root.k))
            const peak = z < 1 ? 1 + Math.exp(-Math.PI * z / Math.sqrt(1 - z * z)) : 1
            console.warn(`stiffness ${root.k}, damping ${root.c}: zeta ${z.toFixed(2)}, overshoot ${((peak - 1) * 100).toFixed(1)}%\n`
                + ranked.map((r, i) => `  ${i + 1}. SpringAnimation { spring: ${r.s}; damping: ${r.d} }  rms ${(r.e / root.rounds * 100).toFixed(2)}%  overshoot ${((r.peak / root.rounds - 1) * 100).toFixed(1)}%`).join("\n"))
            Qt.quit()
        }
    }
}
