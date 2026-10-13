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
        if (playing.length) {
            let bestPlaying = playing[0]
            let bestScore = -1
            for (const player of playing) {
                const score = (player.trackTitle ? 1 : 0)
                    + (player.trackArtist ? 3 : 0)
                    + (player.trackAlbum ? 2 : 0)
                    + (player.trackArtUrl ? 1 : 0)
                const recency = lastActive[player.dbusName] ?? 0
                const bestRecency = lastActive[bestPlaying.dbusName] ?? 0
                if (score > bestScore || (score === bestScore && recency > bestRecency)) {
                    bestPlaying = player
                    bestScore = score
                }
            }
            return bestPlaying
        }
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
