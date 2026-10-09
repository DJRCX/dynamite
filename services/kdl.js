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
                    binds.push({ key: binding.name, action: action.name, argv: action.args, args: action.args.join(" "), category: categoryAt(binding.line), source: fileName || "config.kdl" });
                }
            }
            walk(node.children);
        }
    }
    walk(nodes);
    return binds;
}
