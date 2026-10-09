import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The session lock: one surface per output while Lock.locked.
Scope {
    WlSessionLock {
        locked: Lock.locked
        WlSessionLockSurface {
            id: surface
            color: "black"
            LockSurface { anchors.fill: parent }
        }
    }
}
