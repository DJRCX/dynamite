pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.state
import "kdl.js" as Kdl

Singleton {
    id: root
    property var binds: []
    property var roots: []
    property var contents: ({})
    readonly property string configDir: Quickshell.env("DYNAMITE_NIRI_CONFIG_DIR") || (Quickshell.env("HOME") + "/.config/niri")
    property var pendingCommand: []

    function refresh(): void { scanner.running = true }
    function addFile(path: string): void {
        if (!path) return;
        for (let i = 0; i < watchedFiles.count; i++)
            if (watchedFiles.get(i).filePath === path) return;
        watchedFiles.append({ filePath: path });
    }
    function normalize(path: string): string {
        const parts = [];
        for (const part of path.split("/")) {
            if (!part || part === ".") continue;
            if (part === "..") { if (parts.length) parts.pop(); }
            else parts.push(part);
        }
        return (path.startsWith("/") ? "/" : "") + parts.join("/");
    }
    function resolveInclude(fromFile: string, include: string): string {
        if (include.startsWith("/")) return normalize(include);
        if (include.startsWith("~/")) return normalize(Quickshell.env("HOME") + include.slice(1));
        const slash = fromFile.lastIndexOf("/");
        return normalize((slash >= 0 ? fromFile.slice(0, slash + 1) : "") + include);
    }
    function updateFile(path: string, value: string): void {
        const next = Object.assign({}, contents);
        next[path] = value;
        contents = next;
        rebuild();
    }
    function rebuild(): void {
        const seen = ({}), combined = [];
        function visit(path) {
            if (seen[path]) return;
            seen[path] = true;
            addFile(path);
            if (contents[path] === undefined) return;
            const source = contents[path];
            combined.push.apply(combined, Kdl.keybinds(source, path));
            for (const ref of Kdl.includes(Kdl.parse(source))) visit(resolveInclude(path, ref));
        }
        for (const path of roots) visit(path);
        binds = combined;
    }
    function search(query: string): var {
        const q = query.trim().toLowerCase();
        return binds.filter(bind => {
            if (!bind.title) return false;
            const searchable = [bind.title, bind.action, bind.args, bind.key.replace(/\+/g, " "), bind.category].join(" ").toLowerCase();
            return !q || searchable.includes(q);
        });
    }
    function keyParts(chord: string): var {
        const labels = { mod: "Super", ctrl: "Ctrl", control: "Ctrl", alt: "Alt", shift: "Shift",
            slash: "/", backslash: "\\", comma: ",", period: ".", minus: "-", equal: "=", space: "Space",
            return: "Enter", escape: "Esc", tab: "Tab", backspace: "Backspace", delete: "Delete",
            xf86monbrightnessup: "Brightness Up", xf86monbrightnessdown: "Brightness Down" };
        return String(chord || "").split("+").filter(Boolean).map(part => labels[part.toLowerCase()] || part);
    }
    function run(bind: var): void {
        const args = (bind.argv || (bind.args ? bind.args.split(/\s+/) : [])).slice();
        const action = bind.action;
        pendingCommand = ["niri", "msg", "action", action];
        if (action === "spawn" || action === "spawn-sh") pendingCommand = pendingCommand.concat(["--"]).concat(args);
        else pendingCommand = pendingCommand.concat(args);
        Island.close();
        runDelay.restart();
    }

    Timer { id: runDelay; interval: 120; onTriggered: Quickshell.execDetached(root.pendingCommand) }

    Process {
        id: scanner
        command: ["find", root.configDir, "-maxdepth", "1", "-type", "f", "-name", "*.kdl"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.roots = text.trim().split("\n").filter(Boolean);
                root.contents = ({});
                root.rebuild();
            }
        }
    }
    ListModel { id: watchedFiles }
    Instantiator {
        model: watchedFiles
        delegate: FileView {
            required property string filePath
            path: filePath
            watchChanges: true
            printErrors: false
            onLoaded: root.updateFile(path, text())
            onFileChanged: reload()
        }
    }
    Component.onCompleted: refresh()
}
