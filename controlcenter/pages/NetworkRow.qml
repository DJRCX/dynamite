import QtQuick
import qs.components
import qs.services
import qs.state
import qs.theme

// One Wi-Fi network. Known/open networks connect on click; secured unknown ones expand into a password field.
DeviceRow {
    id: root
    required property var modelData
    readonly property var network: modelData
    property bool expanded: false
    property bool failed: false
    readonly property bool needsPassword: !network.known && !Network.isOpen(network)

    icon: Network.strengthIcon(network.signalStrength)
    title: network.name
    subtitle: failed ? "Couldn't connect" : network.stateChanging ? "Connecting…"
        : [Network.securityLabel(network), network.known ? "Saved" : ""].filter(s => s !== "").join("  ·  ")
    clickable: !network.stateChanging
    height: expanded ? rowHeight + 42 : rowHeight
    Behavior on height { Spring { token: Motion.panel } }

    onExpandedChanged: if (!expanded) password.text = ""
    onClicked: {
        failed = false
        if (needsPassword) {
            expanded = !expanded
            if (expanded) password.forceActiveFocus()
        } else {
            Network.connect(network, "")
        }
    }

    Connections {
        target: root.network
        function onConnectionFailed(reason) { root.failed = true }
        function onConnectedChanged() { if (root.network.connected) root.expanded = false }
    }

    Item {
        width: Metrics.pillHeight; height: Metrics.pillHeight
        Spinner { anchors.centerIn: parent; visible: root.network.stateChanging }
        Icon {
            anchors.centerIn: parent
            visible: !root.network.stateChanging
            name: "chevron_right"
            size: Metrics.iconXs
            color: Theme.textMuted
            rotation: root.expanded ? 90 : 0
            Behavior on rotation { Spring { token: Motion.panel } }
        }
    }

    below: [
        Rectangle {
            x: 8
            width: root.width - 16 - connect.width - 8
            height: Metrics.pillHeight + 4
            radius: height / 2
            color: Theme.track
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }
            TextInput {
                id: password
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Theme.text
                font.family: "Inter"
                font.pointSize: Theme.pt(12)
                clip: true
                enabled: root.expanded
                onActiveFocusChanged: if (!activeFocus && !root.expanded) Island.returnFocus()
                onAccepted: connect.clicked()
                Keys.onEscapePressed: root.expanded = false
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                visible: password.text === ""
                px: 12
                color: Theme.textMuted
                text: "Password"
            }
        },
        PillButton {
            id: connect
            x: root.width - width - 8
            y: 2
            opacity: root.expanded ? 1 : 0
            text: "Connect"
            busy: root.network.stateChanging
            onClicked: {
                if (password.text === "") return
                root.failed = false
                Network.connect(root.network, password.text)
                password.text = ""
            }
        }
    ]
}
