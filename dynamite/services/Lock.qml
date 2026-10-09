pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Session lock state shared by every lock surface: stage, typed text, PAM. lock/LockScreen.qml binds
// WlSessionLock.locked to `locked`.
Singleton {
    id: root
    readonly property bool dev: Quickshell.env("DYNAMITE_DEV") === "1"
    // The nested dev session authenticates against a generated PAM file whose only password is "dynamite".
    readonly property string devPamDir: "/tmp/dynamite-pam"

    // Survives config reloads: a reload must never unlock the session.
    PersistentProperties {
        id: persist
        reloadableId: "dynamite-lock"
        property bool locked: false
    }
    property alias locked: persist.locked
    property string stage: "idle"       // idle | password
    property string text: ""
    property string error: ""
    property bool checking: false
    property bool unlocking: false
    signal failed()

    function lock(): void {
        if (locked) return
        reset()
        locked = true
    }
    function reset(): void {
        stage = "idle"
        text = ""
        error = ""
        checking = false
        unlocking = false
    }
    function activity(): void {
        if (!locked || unlocking) return
        stage = "password"
        idleTimer.restart()
    }
    function type(chars: string): void {
        if (checking || unlocking) return
        activity()
        text += chars
        error = ""
    }
    function backspace(): void {
        if (checking || unlocking) return
        activity()
        text = text.slice(0, -1)
    }
    function submit(): void {
        activity()
        if (checking || unlocking || text === "") return
        checking = true
        pam.start()
    }

    PamContext {
        id: pam
        configDirectory: root.dev ? root.devPamDir : "/etc/pam.d"
        config: root.dev ? "dynamite-dev" : "login"
        onPamMessage: if (responseRequired) respond(root.text)
        onCompleted: result => {
            root.checking = false
            if (result === PamResult.Success) {
                root.unlocking = true
                unlockTimer.restart()
            } else {
                root.text = ""
                root.error = "Wrong password"
                root.failed()
            }
        }
        onError: error => {
            // A rejected password also arrives as completed(Failed), which handles it.
            if (error === PamError.TryAuthFailed) return
            console.warn("[Dynamite] lock: PAM error", PamError.toString(error))
            root.checking = false
            root.text = ""
            root.error = "Couldn't check the password"
            root.failed()
        }
    }

    // Let the surfaces fade out (fade spring) before the compositor drops the lock.
    Timer {
        id: unlockTimer
        interval: 550
        onTriggered: {
            root.locked = false
            root.reset()
        }
    }
    Timer {
        id: idleTimer
        interval: 10000
        onTriggered: if (!root.checking && !root.unlocking) {
            root.stage = "idle"
            root.text = ""
            root.error = ""
        }
    }

    readonly property string facePath: Quickshell.env("HOME") + "/.face"
    property bool hasFace: false
    Process {
        running: true
        command: ["test", "-r", root.facePath]
        onExited: code => root.hasFace = code === 0
    }

    Process {
        running: root.dev
        command: ["sh", "-c", 'mkdir -p "$1" && printf "auth required pam_exec.so quiet expose_authtok %s\\n" "$2" > "$1/dynamite-dev"',
                  "sh", root.devPamDir, Quickshell.shellDir + "/dev/pam-check.sh"]
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function isLocked(): bool { return root.locked }
    }
    IpcHandler {
        target: "lockdev"
        enabled: root.dev
        function submit(password: string): void {
            root.activity()
            root.text = password
            root.submit()
        }
    }
}
