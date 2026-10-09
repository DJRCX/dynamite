pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root
    readonly property bool dev: Quickshell.env("DYNAMITE_DEV") === "1"
    readonly property bool dnd: Config.notifications.dnd

    // Newest first: { key, appName, appIcon, image, summary, body, critical, actions: [{ text, invoke() }], time,
    //                 notification (null for injected) }
    property var list: []
    // Entries that still need a toast (Phase 9 consumes these).
    property var toastQueue: []
    property int nextKey: 1

    signal added(var entry)

    function setDnd(on: bool): void { Config.notifications.dnd = on }

    function push(entry: var): void {
        entry.key = nextKey++
        entry.time = new Date()
        list = [entry].concat(list)
        if (!dnd) toastQueue = toastQueue.concat([entry])
        added(entry)
    }
    function remove(key: int): void {
        list = list.filter(e => e.key !== key)
        toastQueue = toastQueue.filter(e => e.key !== key)
    }
    function dismiss(entry: var): void {
        if (entry.notification) entry.notification.dismiss()
        remove(entry.key)
    }
    function clear(): void {
        for (const entry of list)
            if (entry.notification) entry.notification.dismiss()
        list = []
        toastQueue = []
    }
    function takeToast(): var {
        if (!toastQueue.length) return null
        const entry = toastQueue[0]
        toastQueue = toastQueue.slice(1)
        return entry
    }
    function dropToast(key: int): void { toastQueue = toastQueue.filter(e => e.key !== key) }
    function isLive(key: int): bool { return list.some(e => e.key === key) }

    LazyLoader {
        active: !root.dev
        NotificationServer {
            keepOnReload: true
            actionsSupported: true
            imageSupported: true
            bodyMarkupSupported: false
            onNotification: n => {
                n.tracked = true
                const entry = {
                    appName: n.appName || "Notification",
                    appIcon: n.appIcon || "",
                    image: n.image || "",
                    summary: n.summary,
                    body: n.body,
                    critical: n.urgency === NotificationUrgency.Critical,
                    actions: Array.from(n.actions ?? []).map(a => ({ text: a.text, invoke: () => a.invoke() })),
                    notification: n
                }
                root.push(entry)
                n.closed.connect(() => root.remove(entry.key))
            }
        }
    }

    IpcHandler {
        target: "notifs"
        function debugInject(summary: string, body: string): void {
            root.push({ appName: "notify-send", appIcon: "", image: "", summary: summary, body: body,
                        critical: false, actions: [], notification: null })
        }
        // Dev: `app` and an icon name; `critical` keeps the toast up until clicked; `action` adds one action pill.
        function debugInjectFull(app: string, icon: string, summary: string, body: string, critical: bool, action: string): void {
            root.push({ appName: app, appIcon: icon, image: "", summary: summary, body: body, critical: critical,
                        actions: action ? [{ text: action, invoke: () => console.info("[Dynamite] notification action", action) }] : [],
                        notification: null })
        }
        function clear(): void { root.clear() }
    }
}
