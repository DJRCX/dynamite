pragma Singleton
import QtQuick
import Quickshell
import qs.config

Singleton {
    readonly property bool reduced: Config.motion.reduceMotion
    readonly property QtObject island: QtObject {
        readonly property real spring: Config.motion.islandSpring
        readonly property real damping: Config.motion.islandDamping
    }
    readonly property QtObject panel: QtObject {
        readonly property real spring: Config.motion.panelSpring
        readonly property real damping: Config.motion.panelDamping
    }
    readonly property QtObject fade: QtObject {
        readonly property real spring: Config.motion.fadeSpring
        readonly property real damping: Config.motion.fadeDamping
    }
}
