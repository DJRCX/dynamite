pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property var players: Mpris.players.values
    // Chosen by scrolling the media card; cleared when that player goes away.
    property var pinned: null
    // dbusName → ms timestamp of the last time it started playing.
    property var lastActive: ({})

    readonly property var activePlayer: {
        if (pinned && players.includes(pinned)) return pinned
        const playing = players.filter(p => p.isPlaying)
        if (playing.length) return playing[playing.length - 1]
        let best = null
        for (const p of players)
            if (!best || (lastActive[p.dbusName] ?? 0) > (lastActive[best.dbusName] ?? 0)) best = p
        return best
    }

    function cycle(step: int): void {
        if (players.length < 2) return
        const index = players.indexOf(activePlayer)
        pinned = players[(index + step + players.length) % players.length]
    }

    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                if (!modelData.isPlaying) return
                const next = Object.assign({}, root.lastActive)
                next[modelData.dbusName] = Date.now()
                root.lastActive = next
                if (root.pinned && root.pinned !== modelData) root.pinned = null
            }
        }
    }
}
