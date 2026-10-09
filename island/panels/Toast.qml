import QtQuick
import Quickshell
import qs.components
import qs.controlcenter.pages
import qs.state
import qs.theme

// 450 × 67 pill. A queued toast replaces the current one in place: the two layers crossfade.
Item {
    id: root

    property var entryA: null
    property var entryB: null
    property bool showA: true
    property real fadeA: showA ? 1 : 0
    Behavior on fadeA { Spring { token: Motion.panel; epsilon: 0.002 } }

    function present(entry: var): void {
        if (!entry) return
        if (showA ? entry === entryA : entry === entryB) return
        if (showA) { entryB = entry; showA = false }
        else { entryA = entry; showA = true }
    }
    Component.onCompleted: { entryA = Overlays.toast; showA = true }
    Connections {
        target: Overlays
        function onToastChanged() { root.present(Overlays.toast) }
    }

    HoverHandler { onHoveredChanged: Overlays.toastHovered = hovered }
    TapHandler { onTapped: Overlays.activateToast() }

    component Content: Item {
        id: content
        property var entry: null
        anchors.fill: parent
        visible: opacity > 0.01 && entry !== null
        readonly property string iconSource: {
            if (!entry) return ""
            if (entry.image) return entry.image
            if (!entry.appIcon) return ""
            if (entry.appIcon.startsWith("/") || entry.appIcon.startsWith("file:")) return entry.appIcon
            return Quickshell.iconPath(entry.appIcon, true)
        }

        Rectangle {
            x: 12; y: 16
            width: Metrics.toastAvatar; height: width
            radius: width / 2
            color: Theme.subpage
            clip: true
            Image {
                id: avatar
                anchors.centerIn: parent
                width: content.entry?.image ? parent.width : Metrics.launcherIcon
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: content.entry?.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                asynchronous: true
                mipmap: true
                source: content.iconSource
                visible: status === Image.Ready
            }
            Txt {
                anchors.centerIn: parent
                visible: !avatar.visible
                px: 13; weight: Font.DemiBold
                color: Theme.accent
                text: (content.entry?.appName ?? "?").charAt(0).toUpperCase()
            }
        }
        Txt {
            x: 60; y: 11
            width: actions.x - x - 10
            px: 10.5
            color: Theme.textSecondary
            text: content.entry?.appName ?? ""
        }
        Txt {
            x: 60; y: 26
            width: actions.x - x - 10
            px: 13; weight: Font.Bold
            text: content.entry?.summary ?? ""
        }
        Txt {
            x: 60; y: 43
            width: actions.x - x - 10
            px: 10.5
            color: Theme.textSecondary
            text: (content.entry?.body ?? "").replace(/\s*\n\s*/g, " ")
        }
        Row {
            id: actions
            x: parent.width - width - (parent.height - Metrics.pillHeight) / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: (content.entry?.actions ?? []).slice(0, 2)
                PillButton {
                    required property var modelData
                    text: modelData.text
                    onClicked: Overlays.invokeAction(modelData)
                }
            }
        }
    }

    Content { entry: root.entryA; opacity: root.fadeA }
    Content { entry: root.entryB; opacity: 1 - root.fadeA }
}
