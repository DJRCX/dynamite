import QtQuick
import qs.components
import qs.theme

// A sub-page row: icon circle, title + optional subtitle, and a trailing slot (pill, chevron, check).
Rectangle {
    id: root
    property string icon
    property bool highlighted: false
    property string title
    property string subtitle
    property real titlePx: 13
    property int titleWeight: Font.DemiBold
    property int iconSize: Metrics.rowIcon
    property int iconX: 8
    property int rowHeight: Metrics.rowHeight
    property bool clickable: false
    default property alias trailing: trail.data
    // Content revealed under the row when the row grows taller than rowHeight.
    property alias below: belowArea.data
    signal clicked()

    width: Metrics.pageContentWidth
    height: rowHeight
    radius: Metrics.rowRadius
    color: Theme.mix(Theme.card, Theme.raised, clickable && area.containsMouse ? 1 : 0)
    clip: true

    property real lit: highlighted ? 1 : 0
    Behavior on lit { Spring { token: Motion.panel; epsilon: 0.002 } }

    MouseArea {
        id: area
        width: root.width
        height: root.rowHeight
        hoverEnabled: root.clickable
        enabled: root.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Rectangle {
        id: badge
        x: root.iconX
        y: (root.rowHeight - height) / 2
        width: root.iconSize; height: root.iconSize
        radius: width / 2
        color: Theme.mix(Theme.chip, Theme.accent, root.lit)
        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: Metrics.iconXs + 2
            color: Theme.mix(Theme.text, Theme.onAccent, root.lit)
        }
    }

    Column {
        x: badge.x + badge.width + 14
        y: (root.rowHeight - height) / 2
        width: trail.x - x - 10
        Txt {
            width: parent.width
            px: root.titlePx; weight: root.titleWeight
            text: root.title
        }
        FadeText {
            width: parent.width
            visible: root.subtitle !== ""
            px: 10.5
            color: Theme.textSecondary
            text: root.subtitle
        }
    }

    Row {
        id: trail
        x: root.width - width - (root.rowHeight - Metrics.pillHeight) / 2
        y: (root.rowHeight - height) / 2
        height: Metrics.pillHeight
        spacing: 8
    }

    Item {
        id: belowArea
        y: root.rowHeight
        width: root.width
        height: Math.max(0, root.height - root.rowHeight)
    }
}
