import QtQuick
import Quickshell
import qs.components
import qs.controlcenter.pages
import qs.controlcenter.tiles
import qs.services
import qs.state
import qs.theme

// Lives inside the status island; the island's size follows GridLayoutModel.pageWidth/pageHeight(Island.ccPage).
Item {
    id: root
    width: GridLayoutModel.width
    height: GridLayoutModel.mainHeight

    // Scanning only runs while its page is on screen.
    readonly property bool wifiOpen: Island.mode === "cc" && Island.ccPage === "wifi"
    readonly property bool bluetoothOpen: Island.mode === "cc" && Island.ccPage === "bluetooth"
    onWifiOpenChanged: Network.scanning = wifiOpen
    onBluetoothOpenChanged: Bluetooth.discover = bluetoothOpen
    Component.onCompleted: { Network.scanning = wifiOpen; Bluetooth.discover = bluetoothOpen }
    Component.onDestruction: { Network.scanning = false; Bluetooth.discover = false }

    Item {
        id: grid
        width: GridLayoutModel.width
        height: GridLayoutModel.mainHeight
        opacity: Island.ccPage === "main" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { Spring { token: Motion.panel; epsilon: 0.002 } }

        Repeater {
            model: ScriptModel { values: GridLayoutModel.items; objectProp: "id" }
            Loader {
                id: cellLoader
                required property var modelData
                readonly property var r: GridLayoutModel.rect(modelData)
                x: r.x; y: r.y
                width: r.w; height: r.h
                sourceComponent: {
                    switch (modelData.kind) {
                    case "tile": return modelData.w === 1 ? toggleComponent : tileComponent
                    case "toggle": return toggleComponent
                    case "slider": return sliderComponent
                    case "notifications": return notificationsComponent
                    default: return null
                    }
                }
                Component { id: tileComponent; Tile { cid: cellLoader.modelData.id } }
                Component { id: toggleComponent; ToggleCircle { cid: cellLoader.modelData.id } }
                Component { id: sliderComponent; SliderCard { cid: cellLoader.modelData.id } }
                Component { id: notificationsComponent; NotificationsCard {} }
            }
        }
    }

    component Page: PanelSlot {
        property string page
        edge: -1
        width: GridLayoutModel.pageWidth(page)
        height: GridLayoutModel.pageHeight(page)
        shown: Island.ccPage === page
    }
    Page { page: "wifi"; content: WifiPage {} }
    Page { page: "bluetooth"; content: BluetoothPage {} }
    Page { page: "sound"; content: SoundPage {} }
    Page { page: "display"; content: DisplayPage {} }
    Page { page: "battery"; content: BatteryPage {} }
    Page { page: "system"; content: SystemPage {} }
}
