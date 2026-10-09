import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

Item {
    id: root
    width: 335
    height: Config.weather.inCalendar ? (Weather.expanded ? 405 : 341) : 277

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date today: clock.date
    property int year: today.getFullYear()
    property int month: today.getMonth()
    property int front: 0

    readonly property var weekdayLetters: ["S", "M", "T", "W", "T", "F", "S"]

    function shift(direction: int): void {
        const next = new Date(year, month + direction, 1)
        year = next.getFullYear()
        month = next.getMonth()
        const incoming = front === 0 ? gridB : gridA
        const outgoing = front === 0 ? gridA : gridB
        incoming.animate = false
        incoming.year = year
        incoming.month = month
        incoming.dx = direction * 24
        incoming.opacity = 0
        incoming.animate = true
        incoming.dx = 0
        incoming.opacity = 1
        outgoing.dx = -direction * 24
        outgoing.opacity = 0
        front = 1 - front
    }

    component RoundButton: Rectangle {
        id: button
        property string icon
        signal clicked()
        width: 28
        height: 28
        radius: 14
        color: Theme.mix(Theme.control, Theme.raised, hover.hovered ? 1 : 0)
        Icon { anchors.centerIn: parent; name: button.icon; size: 13; color: Theme.textSecondary }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: button.clicked() }
    }

    component MonthGrid: Item {
        id: grid
        property int year
        property int month
        property real dx: 0
        property bool animate: true
        x: dx
        width: root.width
        height: root.height
        Behavior on dx { enabled: grid.animate; Spring { token: Motion.panel } }
        Behavior on opacity { enabled: grid.animate; Spring { token: Motion.panel; epsilon: 0.002 } }
        visible: opacity > 0.01

        readonly property date first: new Date(year, month, 1)
        readonly property int lead: first.getDay()

        Repeater {
            model: 42
            Item {
                id: cell
                required property int index
                readonly property date day: new Date(grid.year, grid.month, 1 - grid.lead + index)
                readonly property bool inMonth: day.getMonth() === grid.month
                readonly property bool isToday: day.toDateString() === root.today.toDateString()
                x: 36 + 44 * (index % 7) - width / 2
                y: 90 + 32 * Math.floor(index / 7) - height / 2
                width: 30
                height: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    color: Theme.accent
                    visible: cell.isToday
                }
                Text {
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    color: cell.isToday ? Theme.onAccent : Theme.text
                    opacity: cell.inMonth ? 1 : 0.2
                    font.family: "Inter"
                    font.weight: cell.isToday ? Font.Bold : Font.Medium
                    font.pixelSize: 12
                }
            }
        }
    }

    RoundButton {
        x: 14
        y: 14
        icon: "arrow_back"
        onClicked: root.shift(-1)
    }
    RoundButton {
        x: 293
        y: 14
        icon: "arrow_forward"
        onClicked: root.shift(1)
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 28
        text: Qt.locale("en_US").standaloneMonthName(root.month) + " " + root.year
        color: Theme.text
        font.family: "Inter"
        font.weight: Font.DemiBold
        font.pixelSize: 13
    }

    Repeater {
        model: 7
        Text {
            required property int index
            x: 36 + 44 * index - width / 2
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 59
            text: root.weekdayLetters[index]
            color: Theme.textMuted
            font.family: "Inter"
            font.weight: Font.Medium
            font.pixelSize: 10
        }
    }

    Item {
        anchors.fill: parent
        clip: false
        MonthGrid { id: gridA; opacity: 1 }
        MonthGrid { id: gridB; opacity: 0 }
    }
    Component.onCompleted: { gridA.year = year; gridA.month = month; Weather.refresh() }
    Rectangle {
        id: weatherStrip
        visible: Config.weather.inCalendar
        x: 14; y: 279; width: parent.width - 28; height: Weather.expanded ? 114 : 50; radius: 14; color: Theme.card
        Behavior on height { Spring { token: Motion.panel } }
        Row {
            x: 10; y: 5; width: parent.width - 20; height: 40; spacing: 4
            MouseArea {
                width: 112; height: 40; onClicked: Weather.expanded = !Weather.expanded
                Row { anchors.fill: parent; spacing: 4
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: Weather.icon(Weather.code, Weather.isDay); size: 20; color: Theme.accent }
                    Column { anchors.verticalCenter: parent.verticalCenter; spacing: 0
                        Text { text: Math.round(Weather.temperature) + "°"; color: Theme.text; font.weight: Font.DemiBold; font.pixelSize: 15 }
                        Text { text: Weather.error || Weather.description(Weather.code); color: Theme.textSecondary; font.pixelSize: 10; elide: Text.ElideRight; width: 86 }
                    }
                }
            }
            Repeater {
                model: 5
                Column {
                    required property int index
                    width: (weatherStrip.width - 136) / 5; height: 40; spacing: 0
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.daily.time?.[index] ? Qt.formatDate(new Date(Weather.daily.time[index] + "T12:00:00"), "ddd") : "—"; color: Theme.textMuted; font.pixelSize: 9 }
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.daily.weather_code?.[index] !== undefined ? Weather.icon(Weather.daily.weather_code[index], true) : "cloud"; size: 14; color: Theme.textSecondary }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.daily.temperature_2m_max?.[index] !== undefined ? Math.round(Weather.daily.temperature_2m_max[index]) + "° / " + Math.round(Weather.daily.temperature_2m_min[index]) + "°" : ""; color: Theme.textSecondary; font.pixelSize: 9 }
                }
            }
        }
        Row {
            visible: Weather.expanded; x: 8; y: 54; width: parent.width - 16; height: 50; spacing: 3
            Repeater { model: 12; delegate: Column {
                required property int index
                width: (weatherStrip.width - 20) / 12; spacing: 1
                readonly property int hourIndex: {
                    const times = Weather.hourly.time || []
                    const next = times.findIndex(t => new Date(t).getTime() >= Date.now())
                    return Math.max(0, next) + index
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.hourly.time?.[parent.hourIndex] ? Qt.formatDateTime(new Date(Weather.hourly.time[parent.hourIndex]), "h AP") : ""; color: Theme.textMuted; font.pixelSize: 8 }
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.hourly.weather_code?.[parent.hourIndex] !== undefined ? Weather.icon(Weather.hourly.weather_code[parent.hourIndex], true) : "cloud"; size: 12; color: Theme.textSecondary }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.hourly.temperature_2m?.[parent.hourIndex] !== undefined ? Math.round(Weather.hourly.temperature_2m[parent.hourIndex]) + "°" : ""; color: Theme.textSecondary; font.pixelSize: 9 }
            } } }
    }

    property real wheelAccum: 0
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.wheelAccum += event.angleDelta.y
            if (Math.abs(root.wheelAccum) < 120) return
            root.shift(root.wheelAccum > 0 ? -1 : 1)
            root.wheelAccum = 0
        }
    }
}
