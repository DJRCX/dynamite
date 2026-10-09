pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.services

// Transient center-island modes: the volume/brightness OSD and the notification toast queue
// (priority rules in the architecture spec).
Singleton {
    id: root

    // ── OSD ──
    property string osdKind: "volume"
    property string osdReturn: "collapsed"
    readonly property real osdValue: osdKind === "brightness" ? Brightness.focusedValue / 100 : Audio.volume
    readonly property bool osdMuted: osdKind === "volume" && Audio.muted

    function showOsd(kind: string): void {
        const mode = Island.mode
        if (!["collapsed", "clock", "osd"].includes(mode)) return
        osdKind = kind
        if (mode !== "osd") {
            osdReturn = mode
            Island.open("osd")
        }
        osdTimer.restart()
    }
    Timer {
        id: osdTimer
        interval: 1600
        onTriggered: {
            if (Island.mode !== "osd") return
            if (root.osdReturn === "clock") Island.open("clock", Island.screenName)
            else Island.close()
        }
    }
    Connections {
        target: Audio
        function onOsdRequested(kind) { root.showOsd(kind) }
    }
    Connections {
        target: Brightness
        function onOsdRequested(kind) { root.showOsd(kind) }
    }

    // ── Polkit ──
    Connections {
        target: Polkit
        function onRequested() { Island.open("polkit") }
        function onFinished() { if (Island.mode === "polkit") Island.close() }
    }

    // ── Toasts ──
    property var toast: null
    property bool toastHovered: false

    function pumpToasts(): void {
        if (!Notifs.toastQueue.length) return
        const mode = Island.mode
        if (mode === "cc") {
            // The CC's notifications card already shows them.
            for (const entry of Notifs.toastQueue) Notifs.dropToast(entry.key)
            return
        }
        if (["collapsed", "clock", "osd"].includes(mode)) showNext()
    }
    function showNext(): void {
        const entry = Notifs.takeToast()
        if (!entry) {
            if (Island.mode === "toast") Island.close()
            return
        }
        toast = entry
        if (Island.mode !== "toast") Island.open("toast")
        toastTimer.restart()
    }
    function activateToast(): void {
        Island.open("cc")
    }
    function invokeAction(action: var): void {
        const entry = toast
        action.invoke()
        if (entry) Notifs.dismiss(entry)
        showNext()
    }

    Timer {
        id: toastTimer
        interval: Config.notifications.toastSeconds * 1000
        running: Island.mode === "toast" && !root.toastHovered && !(root.toast?.critical ?? false)
        onTriggered: root.showNext()
    }
    Connections {
        target: Notifs
        function onToastQueueChanged() { Qt.callLater(root.pumpToasts) }
        function onListChanged() {
            if (Island.mode === "toast" && root.toast && !Notifs.isLive(root.toast.key)) root.showNext()
        }
    }
    Connections {
        target: Island
        function onModeChanged() {
            if (Island.mode !== "toast") root.toastHovered = false
            Qt.callLater(root.pumpToasts)
        }
    }
}
