import QtQuick
import qs.theme

SpringAnimation {
    property QtObject token: Motion.island
    spring: Motion.reduced ? 30 : token.spring
    damping: Motion.reduced ? 1.0 : token.damping
    epsilon: 0.01
}
