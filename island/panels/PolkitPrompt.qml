import QtQuick
import qs.components
import qs.services
import qs.state
import qs.theme

// 430 × 266. Enter submits, Esc/Cancel cancel the request; a wrong password shakes the field.
Item {
    id: root
    readonly property QtObject flow: Polkit.flow
    readonly property bool busy: flow !== null && !flow.isResponseRequired && !flow.isCompleted
    property string error: ""

    function reset(): void {
        input.text = ""
        error = ""
        input.forceActiveFocus()
    }
    function submit(): void {
        if (!flow || busy) return
        error = ""
        Polkit.submit(input.text)
    }
    Component.onCompleted: reset()
    Connections {
        target: Island
        function onModeChanged() { if (Island.mode === "polkit") root.reset() }
    }
    Connections {
        target: Polkit
        function onFailedAttempt() {
            input.text = ""
            root.error = root.flow?.supplementaryMessage || "Wrong password"
            field.shakeSprung = false
            field.shake = Metrics.shakeOffset
            field.shakeSprung = true
            field.shake = 0
            input.forceActiveFocus()
        }
    }

    Rectangle {
        x: 15; y: 13
        width: 30; height: 30
        radius: width / 2
        color: Theme.accent
        Icon {
            anchors.centerIn: parent
            name: "lock"
            size: 13
            color: Theme.onAccent
        }
    }
    Txt {
        x: 56; y: 18
        width: parent.width - x - 15
        px: 16; weight: Font.Medium
        text: "Authentication required"
    }

    Rectangle {
        x: 15; y: 55
        width: 400; height: 73
        radius: 12
        color: Theme.panel
        Txt {
            x: 12; y: 9
            width: parent.width - 24
            px: 13; weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            lineHeight: 0.95
            text: root.flow?.message ?? ""
        }
        Txt {
            x: 12; y: 50
            width: parent.width - 24
            px: 10
            color: Theme.textSecondary
            text: root.flow?.actionId ?? ""
        }
    }

    Txt {
        x: 15; y: 142
        px: 10.5
        color: Theme.textMuted
        text: Polkit.prompt()
    }

    Rectangle {
        id: field
        property real shake: 0
        property bool shakeSprung: true
        Behavior on shake { enabled: field.shakeSprung; Spring { token: Motion.island } }
        x: 15 + shake; y: 168
        width: 400; height: 39
        radius: height / 2
        color: Theme.island
        border.width: 1
        property real focusness: input.activeFocus ? 1 : 0
        Behavior on focusness { Spring { token: Motion.panel; epsilon: 0.002 } }
        border.color: Theme.mix(Theme.raised, Theme.accent, 0.12 * focusness)

        Rectangle {
            x: 7; y: 7
            width: 26; height: 26
            radius: width / 2
            color: Theme.raised
            Icon {
                anchors.centerIn: parent
                name: "lock"
                size: 11
                color: Theme.textSecondary
            }
        }
        TextInput {
            id: input
            x: 48
            width: parent.width - x - 16
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            font.family: "Inter"
            font.pointSize: Theme.pt(13)
            echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "•"
            selectionColor: Theme.accentContainer
            clip: true
            readOnly: root.busy
            cursorDelegate: Rectangle {
                width: 2; height: 16
                y: (input.height - height) / 2
                color: Theme.text
                visible: input.cursorVisible
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { Polkit.cancel(); event.accepted = true }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.submit(); event.accepted = true }
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                px: 13
                color: Theme.textMuted
                text: "Enter your password"
            }
        }
    }

    Txt {
        x: 15
        y: 220 + (32 - height) / 2
        width: 200
        px: 10.5
        color: Theme.danger
        wrapMode: Text.Wrap
        maximumLineCount: 2
        text: root.error
        opacity: root.error !== "" ? 1 : 0
        Behavior on opacity { Spring { token: Motion.fade; epsilon: 0.002 } }
    }

    component Button: Rectangle {
        id: button
        property string text
        property bool primary: false
        property bool busy: false
        signal clicked()
        height: 32
        radius: height / 2
        property real hover: area.containsMouse ? 1 : 0
        Behavior on hover { Spring { token: Motion.panel; epsilon: 0.002 } }
        color: primary ? Theme.mix(Theme.accent, Theme.knob, 0.15 * hover) : Theme.mix(Theme.raised, Theme.chip, hover)
        Txt {
            anchors.centerIn: parent
            px: 12.5; weight: Font.DemiBold
            color: button.primary ? Theme.onAccent : Theme.text
            text: button.text
            opacity: button.busy ? 0 : 1
        }
        Spinner {
            anchors.centerIn: parent
            visible: button.busy
            color: Theme.onAccent
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
    Button {
        x: 224; y: 220
        width: 72
        text: "Cancel"
        onClicked: Polkit.cancel()
    }
    Button {
        x: 305; y: 220
        width: 110
        primary: true
        busy: root.busy
        text: "Authenticate"
        onClicked: root.submit()
    }
}
