import QtQuick
import qs.theme

// Looping progress glyph (a loop, not a transition, so a linear rotation is fine).
Icon {
    id: root
    property bool running: visible
    name: "progress_activity"
    size: 14
    color: Theme.textSecondary
    RotationAnimation on rotation {
        running: root.running
        loops: Animation.Infinite
        from: 0; to: 360
        duration: 900
    }
}
