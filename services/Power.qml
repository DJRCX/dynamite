pragma Singleton
import QtQuick
import Quickshell

// Session actions. In the nested dev session they are logged instead of run (they'd hit the real machine).
Singleton {
    id: root
    readonly property bool dryRun: Quickshell.env("DYNAMITE_DEV") === "1"

    function run(command: var): void {
        if (dryRun) { console.info("[Dynamite] power (dry run)", command.join(" ")); return }
        Quickshell.execDetached(command)
    }
    function lock(): void { Lock.lock() }
    function suspend(): void {
        Lock.lock()
        suspendLater.restart()
    }
    function logout(): void { run(["niri", "msg", "action", "quit", "--skip-confirmation"]) }
    function reboot(): void { run(["systemctl", "reboot"]) }
    function poweroff(): void { run(["systemctl", "poweroff"]) }

    // Give the lock surface a moment to map before the machine sleeps.
    Timer { id: suspendLater; interval: 400; onTriggered: root.run(["systemctl", "suspend"]) }
}
