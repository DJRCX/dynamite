pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

// The polkit agent. In the nested dev session another agent owns the registration, so a fake flow
// (`polkit preview`) stands in; its password is "dynamite".
Singleton {
    id: root
    readonly property bool dev: Quickshell.env("DYNAMITE_DEV") === "1"
    property QtObject previewFlow: null
    readonly property QtObject flow: previewFlow ?? agent.item?.flow ?? null
    readonly property bool registered: agent.item?.isRegistered ?? false

    signal requested()
    signal failedAttempt()
    signal finished()

    function prompt(): string {
        const text = (flow?.inputPrompt ?? "").replace(/[:\s]+$/, "")
        return text === "" ? "Password" : text
    }
    function submit(value: string): void { flow?.submit(value) }
    function cancel(): void { flow?.cancelAuthenticationRequest() }

    LazyLoader {
        id: agent
        active: !root.dev
        PolkitAgent {
            onAuthenticationRequestStarted: root.requested()
        }
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() { root.failedAttempt() }
        function onIsCompletedChanged() {
            if (!root.flow?.isCompleted) return
            root.finished()
            root.previewFlow = null
        }
    }

    component PreviewFlow: QtObject {
        id: flow
        property string message: "Authentication is needed to run `/usr/bin/true' as the super user"
        property string actionId: "org.freedesktop.policykit.exec"
        property string iconName: ""
        property string inputPrompt: "Password: "
        property bool responseVisible: false
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        property bool isResponseRequired: true
        property bool isCompleted: false
        property bool isSuccessful: false
        property bool isCancelled: false
        property bool failed: false
        signal authenticationFailed()
        signal authenticationSucceeded()
        signal authenticationRequestCancelled()

        property string pending: ""
        property Timer check: Timer {
            interval: 700
            onTriggered: {
                if (flow.pending === "dynamite") {
                    flow.isSuccessful = true
                    flow.authenticationSucceeded()
                    flow.isCompleted = true
                } else {
                    flow.failed = true
                    flow.supplementaryMessage = "Sorry, that didn't work. Please try again."
                    flow.supplementaryIsError = true
                    flow.authenticationFailed()
                    flow.isResponseRequired = true
                }
            }
        }
        function submit(value: string): void {
            pending = value
            isResponseRequired = false
            check.restart()
        }
        function cancelAuthenticationRequest(): void {
            isCancelled = true
            authenticationRequestCancelled()
            isCompleted = true
        }
    }
    Component { id: previewComponent; PreviewFlow {} }

    IpcHandler {
        target: "polkit"
        enabled: root.dev
        function preview(): void {
            root.previewFlow = previewComponent.createObject(root)
            root.requested()
        }
        function previewSubmit(value: string): void { root.previewFlow?.submit(value) }
    }
}
