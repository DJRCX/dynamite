pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme

// Every installed theme (bundled, then generated ones in the state dir), sorted by name.
Singleton {
    id: root
    // [{ name, label, accent, panel, island, text, preview: [colors] }]
    property var list: []

    function refresh(): void { reader.running = true }
    function apply(name: string): void { Config.appearance.theme = name }
    function indexOf(name: string, among: var): int { return among.findIndex(t => t.name === name) }

    Process {
        id: reader
        running: true
        command: ["sh", "-c", 'for f in "$1"/*.json "$2"/*.json; do [ -f "$f" ] && cat "$f" && printf "\\n\\036\\n"; done',
                  "sh", Theme.bundledDir, Theme.stateDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                for (const chunk of text.split("\u001e")) {
                    if (!chunk.trim()) continue
                    try {
                        const theme = JSON.parse(chunk)
                        if (theme.name && !seen[theme.name]) seen[theme.name] = theme
                    } catch (error) {
                        console.warn("[Dynamite] skipping invalid theme JSON")
                    }
                }
                root.list = Object.values(seen).sort((a, b) => a.name.localeCompare(b.name))
            }
        }
    }
}
