import QtQuick
import Quickshell
import Qt.labs.folderlistmodel
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

Item {
    id: root
    property string tab: "Local"
    property string query: ""
    readonly property string directory: Quickshell.env("DYNAMITE_WALLPAPER_DIR") || Config.wallpaper.dir.replace(/^~/, Quickshell.env("HOME"))
    width: 802
    height: 296
    FolderListModel {
        id: files
        folder: "file://" + root.directory
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderListModel.Time
        sortReversed: true
    }
    Connections {
        target: Island
        function onModeChanged() {
            if (Island.mode === "wallpapers") {
                root.tab = "Local"
                root.query = ""
                Wallhaven.previewing = false
            }
        }
    }
    Column {
        x: 20
        y: 12
        width: parent.width - 40
        spacing: 9
        Row {
            width: parent.width
            height: 28
            spacing: 12
            TextInput {
                id: search
                width: parent.width - 70
                height: 28
                color: Theme.text
                font.pixelSize: 13
                text: root.query
                onTextChanged: root.query = text
                onAccepted: if (root.tab === "Online") Wallhaven.search(root.query, Wallhaven.sort, false)
                Rectangle { z: -1; anchors.fill: parent; radius: 8; color: Theme.field }
            }
            Text { text: root.tab; color: Theme.textSecondary; font.pixelSize: 11 }
        }
        Row {
            spacing: 8
            Repeater {
                model: ["Local", "Online"]
                delegate: Rectangle {
                    required property string modelData
                    width: 62
                    height: 26
                    radius: 13
                    color: root.tab === modelData ? Theme.accent : Theme.chip
                    Text { anchors.centerIn: parent; text: modelData; color: root.tab === modelData ? Theme.onAccent : Theme.text; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.tab = modelData
                            if (modelData === "Online") Wallhaven.search(root.query, Wallhaven.sort, false)
                        }
                    }
                }
            }
            Repeater {
                model: root.tab === "Online" ? ["Toplist", "Hot", "Latest", "Random"] : []
                delegate: Rectangle {
                    required property string modelData
                    readonly property string sortValue: ({"Toplist":"toplist", "Hot":"hot", "Latest":"date_added", "Random":"random"})[modelData]
                    width: 66
                    height: 26
                    radius: 13
                    color: Wallhaven.sort === sortValue ? Theme.accent : Theme.chip
                    Text { anchors.centerIn: parent; text: modelData; color: Wallhaven.sort === parent.sortValue ? Theme.onAccent : Theme.text; font.pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { Wallhaven.sort = parent.sortValue; Wallhaven.search(root.query, Wallhaven.sort, false) }
                    }
                }
            }
        }
        Flickable {
            id: resultsScroller
            width: parent.width
            height: 124
            contentWidth: cards.width
            clip: true
            onAtXEndChanged: if (atXEnd && root.tab === "Online") Wallhaven.loadMore()
            Row {
                id: cards
                spacing: 9
                Repeater {
                    model: root.tab === "Local" ? files : Wallhaven.results
                    delegate: Rectangle {
                        required property var modelData
                        width: 185
                        height: 124
                        radius: 8
                        color: Theme.card
                        Image {
                            anchors.fill: parent
                            source: root.tab === "Local" ? files.get(modelData, "fileUrl") : Wallhaven.sourceUrl(modelData, false)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: root.tab === "Online" && Wallhaven.selected?.id === modelData.id ? 2 : 0
                            border.color: Theme.accent
                            radius: 8
                        }
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            text: root.tab === "Local" ? files.get(modelData, "fileName") : modelData.id
                            color: Theme.text
                            elide: Text.ElideMiddle
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.tab === "Local") Wallpaper.set(files.get(modelData, "filePath"), "")
                                else Wallhaven.choose(modelData)
                            }
                        }
                    }
                }
            }
        }
        Row {
            spacing: 8
            Text {
                width: 475
                text: Wallhaven.error || (Wallhaven.loading ? "Loading…" : "Select an image · Preview before keeping")
                color: Wallhaven.error ? Theme.danger : Theme.textMuted
                font.pixelSize: 10
                elide: Text.ElideRight
            }
            Rectangle {
                visible: root.tab === "Online" && Wallhaven.selected !== null
                width: 82; height: 24; radius: 12; color: Theme.control
                Text { anchors.centerIn: parent; text: "Preview"; color: Theme.text; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; onClicked: Wallhaven.preview(Wallhaven.selected) }
            }
            Rectangle {
                visible: root.tab === "Online" && Wallhaven.selected !== null
                width: 64; height: 24; radius: 12; color: Theme.accent
                Text { anchors.centerIn: parent; text: "Keep"; color: Theme.onAccent; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; onClicked: Wallhaven.keep(Wallhaven.selected) }
            }
            Rectangle {
                visible: Wallhaven.previewing
                width: 70; height: 24; radius: 12; color: Theme.control
                Text { anchors.centerIn: parent; text: "Revert"; color: Theme.text; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; onClicked: Wallhaven.revert() }
            }
        }
    }
}
