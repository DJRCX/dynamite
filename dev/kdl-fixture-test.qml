import QtQuick
import Quickshell
import Quickshell.Io
import "services/kdl.js" as Kdl

ShellRoot {
    id: root
    property string configDir: Quickshell.env("DYNAMITE_KDL_TEST_COPY")
    property var roots: []
    property var files: []
    property var contents: ({})
    property var binds: []

    function normalize(path) {
        const parts = [];
        for (const part of path.split("/")) {
            if (!part || part === ".") continue;
            if (part === "..") { if (parts.length) parts.pop(); }
            else parts.push(part);
        }
        return (path.startsWith("/") ? "/" : "") + parts.join("/");
    }
    function resolve(fromFile, ref) {
        if (ref.startsWith("/")) return normalize(ref);
        const slash = fromFile.lastIndexOf("/");
        return normalize((slash >= 0 ? fromFile.slice(0, slash + 1) : "") + ref);
    }
    function updateFile(path, value) {
        const next = Object.assign({}, contents); next[path] = value; contents = next;
        const reachable = [], seen = ({}), parsedBinds = [];
        function visit(file) {
            if (seen[file]) return;
            seen[file] = true; reachable.push({ path: file });
            if (contents[file] === undefined) return;
            parsedBinds.push.apply(parsedBinds, Kdl.keybinds(contents[file], file));
            for (const include of Kdl.includes(Kdl.parse(contents[file]))) visit(resolve(file, include));
        }
        for (const file of roots) visit(file);
        const same = files.length === reachable.length && files.every((file, index) => file.path === reachable[index].path);
        if (!same) files = reachable;
        binds = parsedBinds;
        console.log("kdl-test: loaded", files.length, "files and", binds.length, "binds; keys:", binds.map(b => b.key).join(","));
    }

    Process {
        id: scanner
        command: ["find", root.configDir, "-maxdepth", "1", "-type", "f", "-name", "*.kdl"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.roots = text.trim().split("\n").filter(Boolean);
                root.files = root.roots.map(path => ({ path }));
            }
        }
    }
    Instantiator {
        model: root.files
        delegate: FileView {
            required property var modelData
            path: modelData.path
            watchChanges: true
            printErrors: false
            onLoaded: root.updateFile(path, text())
            onFileChanged: { console.log("kdl-test: file changed", path); reload(); }
        }
    }
    Component.onCompleted: {
        if (!configDir) throw new Error("DYNAMITE_KDL_TEST_COPY is required");
        scanner.running = true;
        const fixture = Kdl.parse([
            'a { action "escaped \\"quote\\""; raw r#"raw // text"#; path "line\\nnext" }',
            '/- ignored { action }',
            'active key="v" { action r"hello // raw" }',
            '/* outer /* nested */ ok */ last { action }',
            'mixed /- "ignored" keep="yes" /- drop="no" { active }'
        ].join("\n"));
        if (fixture.length !== 4 || fixture[0].children[0].args[0] !== 'escaped "quote"'
                || fixture[0].children[1].args[0] !== "raw // text" || fixture[1].properties.key !== "v"
                || fixture[3].args.length || fixture[3].properties.keep !== "yes" || fixture[3].properties.drop !== undefined)
            throw new Error("KDL tokenizer/parser fixture failed");
        console.log("kdl-test: syntax fixture passed");
    }
}
