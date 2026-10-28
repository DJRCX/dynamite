import QtQuick
import qs.components
import qs.config
import qs.services
import qs.state
import qs.theme

// Wallpaper browsing is scoped to the active theme's own folder.
Item {
    id: root
    width: 802
    height: Metrics.wallpaperPickerHeight

    property string query: ""
    property string tab: "Local"
    property int wallpaperIndex: 0
    property bool galleryFocused: true

    readonly property var activeTheme: Themes.list.find(theme => theme.name === Config.appearance.theme) ?? null
    readonly property string groupId: activeTheme?.accentGroup ?? "neutral"
    readonly property var groupInfo: Themes.accentGroups.find(group => group.id === groupId) ?? null
    readonly property var wallpaperItems: tab === "Local"
        ? Themes.wallpapers.filter(file => file.themeName === Config.appearance.theme
            && (!query.trim() || file.name.toLowerCase().includes(query.trim().toLowerCase())))
        : Wallhaven.results.map(item => ({
            name: item.id,
            image: Wallhaven.sourceUrl(item, false),
            remote: true,
            source: item
        }))
    readonly property var selectedWallpaper: wallpaperItems.length
        ? wallpaperItems[Math.max(0, Math.min(wallpaperIndex, wallpaperItems.length - 1))] : null

    function reset(): void {
        if (Wallhaven.previewing) Wallhaven.revert()
        query = ""
        tab = "Local"
        wallpaperIndex = 0
        // The picker opens ready for thumbnail navigation. Search remains
        // available, and Tab/Up can move focus back to the search field.
        galleryFocused = true
        Themes.refresh()
        searchInput.text = ""
        Qt.callLater(() => searchInput.forceActiveFocus())
    }

    function moveWallpaper(delta: int): void {
        if (!wallpaperItems.length) return
        wallpaperIndex = Math.max(0, Math.min(wallpaperItems.length - 1, wallpaperIndex + delta))
        if (tab === "Online") Wallhaven.choose(wallpaperItems[wallpaperIndex].source)
    }

    function applyWallpaper(item: var): void {
        if (!item) return
        if (item.remote) Wallhaven.keep(item.source, Config.appearance.theme)
        else Wallpaper.set(item.path, "")
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Escape) {
            if (Wallhaven.previewing) Wallhaven.revert()
            Island.close()
        } else if (event.key === Qt.Key_Tab) {
            galleryFocused = !galleryFocused
        } else if (event.key === Qt.Key_Down) {
            galleryFocused = true
        } else if (event.key === Qt.Key_Up) {
            galleryFocused = false
        } else if (galleryFocused && event.key === Qt.Key_Left
                   && (searchInput.text === "" || searchInput.cursorPosition === 0)) {
            moveWallpaper(-1)
        } else if (galleryFocused && event.key === Qt.Key_Right
                   && (searchInput.text === "" || searchInput.cursorPosition === searchInput.text.length)) {
            moveWallpaper(1)
        } else if (galleryFocused && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            applyWallpaper(selectedWallpaper)
        } else if (galleryFocused && event.key === Qt.Key_Space && tab === "Online" && selectedWallpaper) {
            Wallhaven.preview(selectedWallpaper.source)
        } else {
            return
        }
        event.accepted = true
    }

    Component.onCompleted: reset()
    Connections {
        target: Island
        function onModeChanged() { if (Island.mode === "wallpapers") root.reset() }
    }
    Connections {
        target: Themes
        function onWallpapersChanged() { root.wallpaperIndex = 0 }
    }
    onGroupIdChanged: wallpaperIndex = 0

    Timer {
        id: searchDebounce
        interval: 500
        repeat: false
        onTriggered: if (root.tab === "Online") Wallhaven.search(root.query, Wallhaven.sort, false)
    }

    Icon {
        x: 15
        anchors.verticalCenter: searchInput.verticalCenter
        name: "search"
        size: Metrics.iconMd
        color: Theme.textMuted
    }
    TextInput {
        id: searchInput
        x: 42; y: 12
        width: root.width - 68
        height: 19
        text: root.query
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: "Inter"
        font.pointSize: Theme.pt(13)
        selectionColor: Theme.accentContainer
        cursorDelegate: Rectangle {
            width: 2; height: 15
            y: (searchInput.height - height) / 2
            color: Theme.text
            visible: searchInput.cursorVisible
        }
        clip: true
        onTextChanged: {
            root.query = text
            root.wallpaperIndex = 0
            if (root.tab === "Online") searchDebounce.restart()
        }
        Keys.onPressed: event => root.handleKey(event)
        onAccepted: {
            if (root.tab === "Online") Wallhaven.search(root.query, Wallhaven.sort, false)
            else root.galleryFocused = true
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text === ""
            px: 13
            color: Theme.textMuted
            text: root.tab === "Local" ? "Search this theme's wallpapers..." : "Search Wallhaven..."
        }
    }

    Row {
        x: 14; y: 42
        spacing: 5
        Repeater {
            model: ["Local", "Online"]
            delegate: Rectangle {
                required property string modelData
                width: 62; height: 25; radius: 13
                color: root.tab === modelData ? Theme.accent : Theme.chip
                Txt {
                    anchors.centerIn: parent
                    px: 9
                    color: root.tab === modelData ? Theme.onAccent : Theme.text
                    text: modelData
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.tab = modelData
                        root.wallpaperIndex = 0
                        root.galleryFocused = true
                        if (modelData === "Online") Wallhaven.search(root.query, Wallhaven.sort, false)
                    }
                }
            }
        }
    }

    Row {
        x: 153; y: 42
        spacing: 5
        visible: root.tab === "Online"
        Repeater {
            model: ["Toplist", "Hot", "Latest", "Random"]
            delegate: Rectangle {
                required property string modelData
                readonly property string sortValue: ({ "Toplist": "toplist", "Hot": "hot", "Latest": "date_added", "Random": "random" })[modelData]
                width: 65; height: 25; radius: 13
                color: Wallhaven.sort === sortValue ? Theme.accent : Theme.chip
                Txt {
                    anchors.centerIn: parent
                    px: 8.5
                    color: Wallhaven.sort === parent.sortValue ? Theme.onAccent : Theme.text
                    text: modelData
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Wallhaven.sort = parent.sortValue
                        Wallhaven.search(root.query, Wallhaven.sort, false)
                    }
                }
            }
        }
    }

    Txt {
        x: 14; y: 80
        px: 10.5
        color: Theme.textSecondary
        text: "" + (activeTheme?.label ?? Config.appearance.theme) + " wallpapers · " + (groupInfo?.label ?? "Neutral")
    }
    Txt {
        x: root.width - 14 - width; y: 80
        px: 9.5
        color: root.tab === "Online" && Wallhaven.error ? Theme.danger : Theme.textMuted
        text: root.tab === "Local" ? wallpaperItems.length + " available"
            : Wallhaven.error || (Wallhaven.loading ? "Loading…" : wallpaperItems.length + " online")
    }

    Flickable {
        id: gallery
        x: 14; y: 101
        width: root.width - 28; height: Metrics.wallpaperGalleryHeight
        contentWidth: cards.implicitWidth
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Behavior on contentX { Spring { token: Motion.panel } }
        onAtXEndChanged: if (atXEnd && root.tab === "Online") Wallhaven.loadMore()
        Row {
            id: cards
            spacing: Metrics.wallpaperCardGap
            Repeater {
                model: root.wallpaperItems
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    width: Metrics.wallpaperCardWidth
                    height: Metrics.wallpaperCardHeight
                    radius: Metrics.themeCardRadius
                    color: Theme.panel
                    Rectangle {
                        x: 4; y: 4
                        width: parent.width - 8
                        height: Metrics.wallpaperThumbHeight
                        radius: Metrics.rowRadius; clip: true
                        color: Theme.card
                        Image {
                            anchors.fill: parent
                            source: card.modelData.remote ? card.modelData.image : card.modelData.url
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(width * 2, height * 2)
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: card.index === root.wallpaperIndex ? 2 : 0
                            border.color: Theme.accent
                        }
                    }
                    Txt {
                        x: 8; y: Metrics.wallpaperThumbHeight + 13
                        width: parent.width - 16
                        px: 9.5
                        color: card.index === root.wallpaperIndex ? Theme.text : Theme.textSecondary
                        text: card.modelData.name
                        elide: Text.ElideMiddle
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.wallpaperIndex = card.index
                            root.galleryFocused = true
                            searchInput.forceActiveFocus()
                            if (root.tab === "Online") Wallhaven.choose(card.modelData.source)
                            else root.applyWallpaper(card.modelData)
                        }
                    }
                }
            }
        }
        onWidthChanged: root.ensureSelectedVisible()
    }

    function ensureSelectedVisible(): void {
        const pitch = Metrics.wallpaperCardWidth + Metrics.wallpaperCardGap
        const target = wallpaperIndex * pitch - (gallery.width - Metrics.wallpaperCardWidth) / 2
        gallery.contentX = Math.max(0, Math.min(target, gallery.contentWidth - gallery.width))
    }
    onWallpaperIndexChanged: Qt.callLater(ensureSelectedVisible)

    Txt {
        anchors.centerIn: gallery
        visible: root.wallpaperItems.length === 0
        width: gallery.width - 40
        horizontalAlignment: Text.AlignHCenter
        px: 11
        color: root.tab === "Online" && Wallhaven.error ? Theme.danger : Theme.textMuted
        text: root.tab === "Online"
            ? (Wallhaven.error || (Wallhaven.loading ? "Loading wallpapers…" : "No wallpapers found"))
            : "No wallpapers for this theme yet"
    }

    Rectangle { x: 14; y: Metrics.wallpaperFooterDividerY; width: root.width - 28; height: 1; color: Theme.divider }
    Txt {
        x: 15; y: Metrics.wallpaperFooterY
        px: 9.5
        color: Wallpaper.error ? Theme.danger : Theme.textMuted
        text: Wallpaper.error || (root.tab === "Online"
            ? "Enter to keep · Space to preview · Esc to revert"
            : "Enter or click to apply · wallpapers are stored with this theme")
    }
    Txt {
        x: root.width - 14 - width; y: Metrics.wallpaperFooterY
        px: 9.5
        color: Theme.textMuted
        text: "Mod+3: Themes"
    }
}
