.pragma library

function tokenize(source) {
    const out = [];
    let i = 0, line = 1, column = 1;
    function emit(type, value, atLine) { out.push({ type, value, line: atLine }); }
    function advance() { const c = source[i++]; if (c === "\n") { line++; column = 1; } else column++; return c; }
    function isSpace(c) { return c === " " || c === "\t" || c === "\r" || c === "\f"; }
    function skipBlockComment() {
        let depth = 1; advance(); advance();
        while (i < source.length && depth) {
            if (source[i] === "/" && source[i + 1] === "*") { advance(); advance(); depth++; }
            else if (source[i] === "*" && source[i + 1] === "/") { advance(); advance(); depth--; }
            else advance();
        }
    }
    function readQuoted(rawHashes) {
        const startLine = line;
        if (rawHashes >= 0) {
            advance(); // r
            while (source[i] === "#") advance();
            advance(); // opening quote
            let value = "";
            while (i < source.length) {
                if (source[i] === '"') {
                    let j = i + 1, hashes = 0;
                    while (source[j] === "#") { hashes++; j++; }
                    if (hashes === rawHashes) { while (i < j) advance(); return { type: "string", value, line: startLine }; }
                }
                value += advance();
            }
            return { type: "string", value, line: startLine };
        }
        advance();
        let value = "";
        while (i < source.length) {
            const c = advance();
            if (c === '"') break;
            if (c !== "\\") { value += c; continue; }
            if (i >= source.length) break;
            const e = advance();
            if (e === "n") value += "\n";
            else if (e === "r") value += "\r";
            else if (e === "t") value += "\t";
            else if (e === "b") value += "\b";
            else if (e === "f") value += "\f";
            else if (e === "\n") { /* line continuation */ }
            else if (e === "\\" || e === '"' || e === "/") value += e;
            else if (e === "u") {
                if (source[i] === "{") {
                    advance();
                    let hex = "";
                    while (/[0-9a-fA-F]/.test(source[i] || "") && hex.length < 7) hex += advance();
                    if (source[i] === "}") advance();
                    const codepoint = parseInt(hex, 16);
                    if (hex.length && hex.length <= 6 && codepoint <= 0x10ffff) value += String.fromCodePoint(codepoint);
                    else value += "u";
                } else {
                    const hex = source.slice(i, i + 4);
                    if (/^[0-9a-fA-F]{4}$/.test(hex)) { value += String.fromCharCode(parseInt(hex, 16)); for (let n = 0; n < 4; n++) advance(); }
                    else value += "u";
                }
            } else value += e;
        }
        return { type: "string", value, line: startLine };
    }
    while (i < source.length) {
        const c = source[i];
        if (isSpace(c)) { advance(); continue; }
        if (c === "\n" || c === ";") { const at = line; advance(); emit("end", "", at); continue; }
        if (c === "\\") {
            let j = i + 1;
            while (source[j] === " " || source[j] === "\t" || source[j] === "\r") j++;
            if (source[j] === "\n") { while (i <= j) advance(); while (isSpace(source[i])) advance(); continue; }
        }
        if (c === "/" && source[i + 1] === "/") { while (i < source.length && source[i] !== "\n") advance(); continue; }
        if (c === "/" && source[i + 1] === "*") { skipBlockComment(); continue; }
        if (c === "/" && source[i + 1] === "-") { const at = line; advance(); advance(); emit("slashdash", "", at); continue; }
        if (c === "r" && source[i + 1] === '"') { out.push(readQuoted(0)); continue; }
        if (c === "r" && source[i + 1] === "#") {
            let j = i + 1; while (source[j] === "#") j++;
            if (source[j] === '"') { out.push(readQuoted(j - i - 1)); continue; }
        }
        if (c === '"') { out.push(readQuoted(-1)); continue; }
        if (c === "{" || c === "}" || c === "=") { const at = line; emit(c, c, at); advance(); continue; }
        const at = line; let value = "";
        while (i < source.length) {
            const x = source[i];
            if (isSpace(x) || x === "\n" || x === ";" || x === "{" || x === "}" || x === "=" || x === '"') break;
            if (x === "/" && (source[i + 1] === "/" || source[i + 1] === "*" || source[i + 1] === "-")) break;
            value += advance();
        }
        if (value) emit("word", value, at); else advance();
    }
    emit("eof", "", line);
    return out;
}

function parse(source) {
    const tokens = tokenize(source);
    let i = 0;
    function nodeList(inChildren) {
        const nodes = [];
        let pendingDash = false;
        while (tokens[i].type !== "eof" && !(inChildren && tokens[i].type === "}")) {
            if (tokens[i].type === "end") { i++; pendingDash = false; continue; }
            if (tokens[i].type === "slashdash") { i++; pendingDash = true; continue; }
            if (tokens[i].type === "}") { i++; continue; }
            const name = tokens[i++];
            if (name.type !== "word" && name.type !== "string") { continue; }
            const n = { name: name.value, args: [], properties: ({}), children: [], line: name.line };
            let skipNode = pendingDash; pendingDash = false;
            while (tokens[i].type !== "end" && tokens[i].type !== "eof" && tokens[i].type !== "}" && tokens[i].type !== "{") {
                if (tokens[i].type === "slashdash") {
                    i++;
                    if (tokens[i].type === "end" || tokens[i].type === "eof") continue;
                    i++;
                    if (tokens[i - 1].type === "word" && tokens[i].type === "=") { i++; if (tokens[i].type !== "end" && tokens[i].type !== "eof") i++; }
                    continue;
                }
                const first = tokens[i++];
                if (tokens[i].type === "=") {
                    i++;
                    const val = tokens[i++];
                    if (val && (val.type === "word" || val.type === "string")) n.properties[first.value] = val.value;
                } else if (first.type === "word" || first.type === "string") n.args.push(first.value);
            }
            if (tokens[i].type === "{") { i++; n.children = nodeList(true); if (tokens[i].type === "}") i++; }
            if (!skipNode) nodes.push(n);
            if (tokens[i].type === "end") i++;
        }
        return nodes;
    }
    return nodeList(false);
}

function includes(nodes) {
    let out = [];
    for (const node of nodes || []) {
        if (node.name === "include" && node.args.length) out.push(node.args[0]);
        out = out.concat(includes(node.children));
    }
    return out;
}

function keybinds(source, fileName) {
    const nodes = parse(source), binds = [];
    const lines = source.split(/\r?\n/);
    function categoryAt(line) {
        for (let n = Math.min(line - 1, lines.length - 1); n >= 0; n--) {
            const m = lines[n].match(/^\s*\/\/\s*[═─━]+\s*(.*?)\s*[═─━]*\s*$/);
            if (m && m[1]) return m[1].trim();
            if (lines[n].trim() && !lines[n].trim().startsWith("//")) break;
        }
        return "Shell & Panels";
    }
    function walk(list) {
        for (const node of list) {
            if (node.name === "include") continue;
            if (node.name === "binds") {
                for (const binding of node.children) {
                    if (!binding.children.length) continue;
                    const action = binding.children[0];
                    const explicitTitle = binding.properties["hotkey-overlay-title"];
                    const title = explicitTitle === "null" ? "" : explicitTitle || actionTitle(action.name, action.args);
                    binds.push({ key: binding.name, title, action: action.name, argv: action.args,
                        args: action.args.join(" "), category: categoryAt(binding.line), source: fileName || "config.kdl" });
                }
            }
            walk(node.children);
        }
    }
    walk(nodes);
    return binds;
}

function actionTitle(action, args) {
    const labels = {
        "show-hotkey-overlay": "Show keyboard shortcuts",
        "toggle-keyboard-shortcuts-inhibit": "Toggle keyboard shortcut inhibition",
        "quit": "Quit Niri",
        "power-off-monitors": "Turn off monitors",
        "focus-column-left": "Focus previous column",
        "focus-column-right": "Focus next column",
        "focus-workspace-up": "Focus previous workspace",
        "focus-workspace-down": "Focus next workspace",
        "move-column-left": "Move column left",
        "move-column-right": "Move column right",
        "close-window": "Close window",
        "maximize-column": "Maximize column",
        "toggle-window-floating": "Toggle window floating",
        "fullscreen-window": "Toggle fullscreen",
        "focus-window-previous": "Focus previous window",
        "focus-window-next": "Focus next window"
    };
    if (labels[action]) return labels[action];
    if (action === "spawn") return spawnTitle(args || []);
    if (action === "spawn-sh") {
        const command = (args || []).join(" ").trim();
        return command ? "Run command: " + command : "Run shell command";
    }
    return String(action || "Shortcut").replace(/[-_]+/g, " ").replace(/\b\w/g, c => c.toUpperCase());
}

function spawnTitle(args) {
    const values = (args || []).map(String);
    const callAt = values.indexOf("call");
    if (callAt >= 0 && values.length > callAt + 2) {
        const target = values[callAt + 1], fn = values[callAt + 2], arg = values[callAt + 3] || "";
        const modes = { cc: "Control Center", media: "Media controls", launcher: "App launcher", power: "Power menu",
            themes: "Themes", wallpapers: "Wallpapers", window: "Window menu", clipboard: "Clipboard history",
            keybinds: "Keyboard shortcuts", calendar: "Calendar" };
        if (target === "island" && (fn === "open" || fn === "toggle") && modes[arg]) return modes[arg];
        const ipc = {
            "lock:lock": "Lock screen", "gamemode:toggle": "Game Mode", "launcher:toggle": "App launcher",
            "powermenu:toggle": "Power menu", "clipboard:toggle": "Clipboard history", "cheatsheet:toggle": "Keyboard shortcuts",
            "settings:open": "Settings", "shell:reload": "Reload Dynamite", "brightness:up": "Increase brightness",
            "brightness:down": "Decrease brightness", "bar:nextWorkspace": "Next workspace", "bar:prevWorkspace": "Previous workspace"
        };
        return ipc[target + ":" + fn] || (target === "island" ? "Open " + (modes[arg] || "island panel") : "Open " + target);
    }
    const executable = values.find(v => v && !v.startsWith("-") && !v.startsWith("%")) || "application";
    if (executable.includes("--app=") || values.some(v => v.startsWith("--app="))) return "Open web app";
    const base = executable.split("/").pop().replace(/\.(?:desktop|bin)$/i, "").toLowerCase();
    if (["kitty", "foot", "alacritty", "wezterm", "xterm"].includes(base)) return "Open terminal";
    if (base === "brightnessctl") {
        const command = values.join(" ").toLowerCase();
        if (/\+|increase|up/.test(command)) return "Increase brightness";
        if (/-|decrease|down/.test(command)) return "Decrease brightness";
        return "Adjust screen brightness";
    }
    const known = { firefox: "Firefox", chromium: "Chromium", "chromium-browser": "Chromium", "google-chrome": "Google Chrome",
        "google-chrome-stable": "Google Chrome", brave: "Brave Browser", "brave-browser": "Brave Browser", thunar: "File manager",
        nautilus: "File manager", dolphin: "File manager", pcmanfm: "File manager" };
    const name = known[base] || base.replace(/[-_]+/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    return "Launch " + name;
}
