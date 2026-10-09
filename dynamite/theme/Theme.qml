pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root
    // Bundled themes first, then generated ones (the wallpaper theme) in ~/.local/state/dynamite/themes.
    readonly property string bundledDir: Quickshell.shellDir + "/themes"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/dynamite/themes"
    property bool fromStateDir: false
    readonly property string name: Config.appearance.theme
    readonly property string themePath: (fromStateDir ? stateDir : bundledDir) + "/" + name + ".json"
    onNameChanged: fromStateDir = false

    readonly property var defaults: ({
        accent: "#49E3AF", accentContainer: "#205543", onAccent: "#0B1A14", island: "#000000",
        panel: "#181614", subpage: "#1F1D1B", card: "#262220", chip: "#322E2B", raised: "#2A2623",
        track: "#0D0B0A", window: "#0A0806", sidebar: "#070707", group: "#141110", field: "#1C1916",
        control: "#1A1816", switchOff: "#3B3734", knob: "#F2EFEA", text: "#EDE7DD",
        textSecondary: "#A39B91", textMuted: "#6B655E", danger: "#E5534B"
    })
    // What's on screen is mix(from, to, blend); a theme change snapshots the current colors and springs blend 0 → 1.
    property var fromColors: defaults
    property var toColors: defaults
    property real blend: 1
    SpringAnimation {
        id: blendSpring
        target: root
        property: "blend"
        to: 1
        spring: Motion.reduced ? 30 : Motion.fade.spring
        damping: Motion.reduced ? 1.0 : Motion.fade.damping
        epsilon: 0.001
    }
    property bool loadedOnce: false
    function value(key: string): color {
        const target = toColors[key] ?? defaults[key]
        return blend >= 1 ? target : mix(Qt.alpha(fromColors[key] ?? target, 1), Qt.alpha(target, 1), blend)
    }
    function apply(json: var): void {
        const next = {}
        for (const key in defaults) next[key] = json[key] || defaults[key]
        if (!loadedOnce) {
            loadedOnce = true
            fromColors = next
            toColors = next
            return
        }
        const snapshot = {}
        // Copy the components: a color read from a property is a live reference, not a value.
        for (const key in defaults) {
            const c = root[key]
            snapshot[key] = Qt.rgba(c.r, c.g, c.b, c.a)
        }
        blendSpring.stop()
        fromColors = snapshot
        toColors = next
        blend = 0
        blendSpring.start()
    }

    readonly property color accent: value("accent")
    readonly property color accentContainer: value("accentContainer")
    readonly property color onAccent: value("onAccent")
    readonly property color island: value("island")
    readonly property color panel: value("panel")
    readonly property color subpage: value("subpage")
    readonly property color card: value("card")
    readonly property color chip: value("chip")
    readonly property color raised: value("raised")
    readonly property color track: value("track")
    readonly property color window: value("window")
    readonly property color sidebar: value("sidebar")
    readonly property color group: value("group")
    readonly property color field: value("field")
    readonly property color control: value("control")
    readonly property color switchOff: value("switchOff")
    readonly property color knob: value("knob")
    readonly property color text: value("text")
    readonly property color textSecondary: value("textSecondary")
    readonly property color textMuted: value("textMuted")
    readonly property color danger: value("danger")
    readonly property color trackOnIsland: Qt.alpha("#FFFFFF", 0.14)
    readonly property color divider: Qt.alpha("#FFFFFF", 0.07)
    readonly property color ghostButton: Qt.alpha("#FFFFFF", 0.08)
    readonly property color lockDim: Qt.alpha("#000000", 0.25)
    readonly property color lockGlass: Qt.alpha(text, 0.25)
    readonly property color lockAvatar: Qt.alpha(text, 0.17)
    readonly property color lockAvatarRing: Qt.alpha(text, 0.30)
    readonly property color batteryTrack: Qt.alpha(text, 0.16)
    readonly property color mediaTint: Qt.alpha(accent, 0.30)
    readonly property color mediaShade: Qt.alpha(Qt.rgba(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 1), 0.55)
    readonly property var fonts: ({
        collapsedClock: ({ family: "Inter", weight: Font.DemiBold, pixelSize: 15 }),
        hoverClock: ({ family: "Inter", weight: Font.DemiBold, pixelSize: 22 }),
        lockTime: ({ family: "Inter", weight: Font.DemiBold, pixelSize: 150 }),
        lockDate: ({ family: "Inter", weight: Font.Medium, pixelSize: 24 }),
        mediaTitle: ({ family: "Inter", weight: Font.DemiBold, pixelSize: 17 }),
        mediaArtist: ({ family: "Inter", weight: Font.Normal, pixelSize: 13 }),
        mediaMeta: ({ family: "Inter", weight: Font.Normal, pixelSize: 11.5 }),
        mediaTime: ({ family: "Inter", weight: Font.Medium, pixelSize: 10.5 }),
        subpageTitle: ({ family: "Inter", weight: Font.DemiBold, pixelSize: 15 }),
        tileTitle: ({ family: "Inter", weight: Font.DemiBold, pixelSize: 14 }),
        cardTitle: ({ family: "Inter", weight: Font.DemiBold, pixelSize: 13 }),
        body: ({ family: "Inter", weight: Font.Normal, pixelSize: 13 }),
        toastSummary: ({ family: "Inter", weight: Font.Bold, pixelSize: 13 }),
        caption: ({ family: "Inter", weight: Font.Normal, pixelSize: 10.5 }),
        weekday: ({ family: "Inter", weight: Font.Medium, pixelSize: 10 }),
        powerAction: ({ family: "Inter", weight: Font.DemiBold, pixelSize: 11.5 }),
        settingsTitle: ({ family: "Inter", weight: Font.DemiBold, pixelSize: 18 }),
        settingsNav: ({ family: "Inter", weight: Font.Medium, pixelSize: 12.5 }),
        settingsRow: ({ family: "Inter", weight: Font.Medium, pixelSize: 12 }),
        code: ({ family: "JetBrainsMono Nerd Font", weight: Font.Normal, pixelSize: 16 })
    })

    // font.pixelSize is an int; fractional pixel sizes from the spec go through font.pointSize (96 dpi).
    function pt(px: real): real { return px * 0.75 }

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }

    FileView {
        id: themeFile
        path: root.themePath
        watchChanges: true
        printErrors: false
        onLoaded: {
            try { root.apply(JSON.parse(text())) }
            catch (error) { console.warn("[Dynamite] invalid theme JSON:", error) }
        }
        onLoadFailed: {
            if (!root.fromStateDir) root.fromStateDir = true
            else console.warn("[Dynamite] theme not found:", Config.appearance.theme)
        }
        onFileChanged: reload()
    }
}
