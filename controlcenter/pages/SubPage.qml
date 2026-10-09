import QtQuick
import QtQuick.Layouts
import qs.components
import qs.state
import qs.theme

// Shared sub-page frame: inner card at (22, 20), header row centered on one line, scrolling content from y 69.
Item {
    id: root
    property string title
    property bool hasSwitch: false
    property bool switchOn: false
    signal switchToggled(bool on)
    default property alias content: body.data
    readonly property int contentWidth: Metrics.pageContentWidth
    // Island height that fits the content without scrolling.
    readonly property real naturalHeight: body.implicitHeight + 69 + 14 + 2 * Metrics.subpageInsetY

    Rectangle {
        id: card
        x: Metrics.subpageInsetX
        y: Metrics.subpageInsetY
        width: Metrics.subpageWidth
        height: root.height - 2 * Metrics.subpageInsetY
        radius: Metrics.subpageRadius
        color: Theme.subpage

        RowLayout {
            x: 14
            y: 21
            width: card.width - 28 - 2
            height: 24
            spacing: 0
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 12
                color: Theme.mix(Theme.raised, Theme.chip, back.containsMouse ? 1 : 0)
                Icon { anchors.centerIn: parent; name: "chevron_left"; size: Metrics.iconXs; color: Theme.textSecondary }
                MouseArea {
                    id: back
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Island.ccPage = "main"
                }
            }
            Txt {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 13
                Layout.fillWidth: true
                px: 15; weight: Font.DemiBold
                text: root.title
            }
            Switch {
                Layout.alignment: Qt.AlignVCenter
                visible: root.hasSwitch
                checked: root.switchOn
                onToggled: on => root.switchToggled(on)
            }
        }

        Flickable {
            x: (card.width - root.contentWidth) / 2
            y: 69
            width: root.contentWidth
            height: card.height - 69 - 12
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: body
                width: root.contentWidth
            }
        }
    }
}
