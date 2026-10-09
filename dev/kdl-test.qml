import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    function parse(text) {
        const binds=[]; let section="Shell & Panels"
        for (const raw of text.split(/\r?\n/)) {
            const line=raw.trim()
            const banner=line.match(/^\/\/\s*[═─━]+\s*(.*?)\s*[═─━]*$/)
            if (banner && banner[1]) section=banner[1].trim()
            const m=line.match(/^([A-Za-z0-9+_-]+)\s+(?:[^{}]*?)\{\s*([A-Za-z0-9_-]+)(?:\s+([^;}]+))?/)
            if (m) binds.push({key:m[1],action:m[2],args:(m[3]||"").trim(),category:section})
        }
        return binds
    }
    FileView {
        path: Quickshell.env("DYNAMITE_KDL_TEST_COPY")
        onLoaded: {
            const binds=root.parse(text())
            if (!binds.length) throw new Error("copied Niri config contains no parsed binds")
            console.log("kdl-test: parsed", binds.length, "binds from copied config")
            Qt.quit()
        }
    }
}
