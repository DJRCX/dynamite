pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string filePath: Quickshell.env("HOME") + "/.config/dynamite/settings.json"
    property alias island: dataView.island
    property alias gameMode: dataView.gameMode
    property alias motion: dataView.motion
    property alias appearance: dataView.appearance
    property alias clock: dataView.clock
    property alias launcher: dataView.launcher
    property alias notifications: dataView.notifications
    property alias controlCenter: dataView.controlCenter
    property alias display: dataView.display
    property alias lock: dataView.lock
    property alias wallpaper: dataView.wallpaper
    property alias terminal: dataView.terminal
    property alias wallhaven: dataView.wallhaven
    property alias clipboard: dataView.clipboard
    property alias power: dataView.power
    property alias idle: dataView.idle
    property alias caffeine: dataView.caffeine
    property alias sysmon: dataView.sysmon
    property alias weather: dataView.weather
    property alias system: dataView.system

    property double ownWriteUntil: 0
    function save(): void {
        ownWriteUntil = Date.now() + 500
        settingsFile.writeAdapter()
    }
    Timer { id: saveTimer; interval: 60; onTriggered: root.save() }

    function setValue(path: string, value: string): bool {
        const parts = path.split(".")
        if (parts.length < 2) return false
        let object = dataView
        for (let i = 0; i < parts.length - 1; ++i) {
            if (!object || object[parts[i]] === undefined) return false
            object = object[parts[i]]
        }
        const key = parts[parts.length - 1]
        if (!object || object[key] === undefined) return false
        let parsed
        try { parsed = JSON.parse(value) }
        catch (error) { parsed = value }
        object[key] = parsed
        save()
        return true
    }

    Process {
        id: makeDirectory
        command: ["/usr/bin/mkdir", "-p", Quickshell.env("HOME") + "/.config/dynamite"]
        running: true
        onExited: (code) => {
            if (code === 0) settingsFile.reload()
            else console.warn("[Dynamite] could not create settings directory", code)
        }
    }

    FileView {
        id: settingsFile
        path: root.filePath
        watchChanges: true
        // Our own writes also fire fileChanged; reloading then would drop changes made since the write.
        onFileChanged: if (Date.now() > root.ownWriteUntil) reload()
        onAdapterUpdated: saveTimer.restart()
        JsonAdapter {
            id: dataView
            property JsonObject island: JsonObject {
                property bool notchMode: false
                property int barHeight: 33
                property int collapsedWidth: 96
                property int expandedHeight: 125
                property int gap: 11
                property int innerPadding: 3
                property int radius: 20
                property int radiusExpanded: 31
                property bool statusCircle: true
                property bool albumCircleWhilePlaying: true
                property int stageLift: 7
            }
            property JsonObject gameMode: JsonObject { property int barHeight: 47; property int clusterGap: 173 }
            property JsonObject motion: JsonObject {
                property real islandSpring: 5.25
                property real islandDamping: 0.35
                property real panelSpring: 6.5
                property real panelDamping: 0.50
                property real fadeSpring: 2.5
                property real fadeDamping: 0.375
                property bool reduceMotion: false
            }
            property JsonObject appearance: JsonObject {
                property string theme: "horizon"
                property string wallpaper: ""
                property string wallpaperMode: "pitch_black"
                property string wallpaperAccent: ""
            }
            property JsonObject clock: JsonObject { property bool use24h: true }
            property JsonObject launcher: JsonObject { property int maxResults: 6 }
            property JsonObject notifications: JsonObject { property int toastSeconds: 4; property bool dnd: false }
            property JsonObject controlCenter: JsonObject { property int columns: 7; property var items: [] }
            property JsonObject display: JsonObject { property bool nightLight: false; property int nightLightTemp: 3700 }
            property JsonObject lock: JsonObject { property int blur: 48 }
            property JsonObject wallpaper: JsonObject {
                property string dir: "~/Pictures/Wallpapers"
                property var current: ({})
                property string transition: "random"
                property real transitionSeconds: 1.2
                property int slideshowMinutes: 0
            }
            property JsonObject terminal: JsonObject {
                property bool kitty: true
                property bool foot: true
                property real opacity: 0.8
                property string background: "black"
            }
            property JsonObject wallhaven: JsonObject {
                property string apiKey: ""
                property string purity: "100"
                property string categories: "110"
                property bool fitScreen: true
            }
            property JsonObject clipboard: JsonObject { property bool autoPaste: true; property bool showImages: true; property int maxItems: 100 }
            property JsonObject power: JsonObject { property bool auto: true; property int saverAt: 50; property int hysteresis: 5 }
            property JsonObject idle: JsonObject { property int lockAfter: 300; property int screenOffAfter: 600 }
            property JsonObject caffeine: JsonObject {
                property double until: 0
                property bool blockSleep: false
                property bool whilePlaying: false
                property bool inGameMode: false
            }
            property JsonObject sysmon: JsonObject { property string tempSensor: "auto"; property int warnTemp: 90 }
            property JsonObject weather: JsonObject {
                property var lat: null
                property var lon: null
                property string place: ""
                property string units: "celsius"
                property bool inCalendar: true
                property bool inHoverClock: false
                property bool onLockScreen: false
            }
            property JsonObject system: JsonObject { property string terminal: "kitty" }
            property JsonObject meta: JsonObject { property bool legacyImported: false }
        }
    }

    // One-time import from the legacy bar's config (the only place Dynamite reads a legacy file).
    FileView {
        id: legacyFile
        path: Quickshell.shellDir + "/../config.json"
        blockLoading: true
        printErrors: false
    }
    function importLegacy(): void {
        if (dataView.meta.legacyImported) return
        let legacy = null
        try { legacy = JSON.parse(legacyFile.text()) } catch (error) { legacy = null }
        if (legacy) {
            if (legacy.wallpaper && !(dataView.wallpaper.current["*"])) {
                dataView.wallpaper.current = Object.assign({}, dataView.wallpaper.current, { "*": legacy.wallpaper })
            }
            if (legacy.wallpaper_dir) dataView.wallpaper.dir = legacy.wallpaper_dir
            if (legacy.theme_mode) dataView.appearance.wallpaperMode = legacy.theme_mode
            if (typeof legacy.terminal_opacity === "number") dataView.terminal.opacity = legacy.terminal_opacity
            if (typeof legacy.weather_lat === "number") dataView.weather.lat = legacy.weather_lat
            if (typeof legacy.weather_lon === "number") dataView.weather.lon = legacy.weather_lon
            if (legacy.weather_units === "fahrenheit" || legacy.weather_units === "celsius") dataView.weather.units = legacy.weather_units
            console.info("[Dynamite] imported settings from the legacy config")
        }
        dataView.meta.legacyImported = true
        save()
    }

    Component.onCompleted: {
        // Ensure the first run writes the full defaults after the directory exists.
        bootstrap.start()
    }
    Timer {
        id: bootstrap
        interval: 350
        onTriggered: {
            if (!settingsFile.exists) root.save()
            root.importLegacy()
        }
    }
}
