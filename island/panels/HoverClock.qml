import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

Item {
    id: root
    width: 254
    height: 116

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property var falloff: [0.10, 0.40, 0.70, 1, 0.90, 0.45, 0.10]
    readonly property var letters: ["S", "M", "T", "W", "T", "F", "S"]

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        spacing: 7
        Text {
            text: Qt.formatTime(clock.date, Config.clock.use24h ? "HH:mm" : "h:mm")
            color: Theme.text
            font.family: Theme.fonts.hoverClock.family
            font.weight: Theme.fonts.hoverClock.weight
            font.pixelSize: Theme.fonts.hoverClock.pixelSize
        }
        Row {
            visible: Config.weather.inHoverClock
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Icon { anchors.verticalCenter: parent.verticalCenter; name: Weather.icon(Weather.code, Weather.isDay); size: 16; color: Theme.textSecondary }
            Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(Weather.temperature) + "°"; color: Theme.textSecondary; font.pixelSize: 13; font.weight: Font.Medium }
        }
    }

    Rectangle {
        x: (root.width - width) / 2
        y: 57
        width: 33
        height: 40
        radius: 9
        color: Theme.panel
    }

    Repeater {
        model: 7
        Item {
            id: column
            required property int index
            readonly property int offset: index - 3
            readonly property bool today: offset === 0
            readonly property date day: {
                const d = new Date(clock.date)
                d.setHours(12, 0, 0, 0)
                d.setDate(d.getDate() + offset)
                return d
            }
            readonly property bool sunday: day.getDay() === 0
            readonly property real fade: root.falloff[index]
            readonly property color tone: today ? Theme.accent : sunday ? Theme.danger : Theme.text

            x: root.width / 2 + offset * 28 - width / 2
            y: 57
            width: 28
            height: 40

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: 11
                text: column.today ? Qt.locale("en_US").dayName(column.day.getDay(), Locale.ShortFormat).toUpperCase()
                                   : root.letters[column.day.getDay()]
                color: column.today ? Theme.text : column.sunday ? Theme.danger : Theme.text
                opacity: column.today ? 1 : column.fade * 0.6
                font.family: "Inter"
                font.weight: column.today ? Font.Bold : Font.Medium
                font.pointSize: Theme.pt(9.5)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: 30
                text: column.day.getDate()
                color: column.tone
                opacity: column.fade
                font.family: "Inter"
                font.weight: column.today ? Font.Bold : Font.Medium
                font.pixelSize: column.today ? 17 : 13
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Island.open("calendar", Island.screenName)
    }
}
