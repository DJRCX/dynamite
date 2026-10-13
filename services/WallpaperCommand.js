.pragma library

// awww treats an omitted --outputs option as every output. Passing "*" as
// an output name is not a wildcard and makes the command fail.
function image(path, output, transition, duration) {
    var command = ["awww", "img", path]
    if (output && output !== "*") command.push("-o", output)
    command.push("--transition-type", transition, "--transition-duration", String(duration))
    return command
}

function randomWallpaper(wallpapers, themeName, currentPath, randomValue) {
    var themed = themeName ? wallpapers.filter(file => file.themeName === themeName) : []
    var candidates = themed.length ? themed : wallpapers
    if (candidates.length > 1) {
        var alternatives = candidates.filter(file => file.path !== currentPath)
        if (alternatives.length) candidates = alternatives
    }
    if (!candidates.length) return ""
    var index = Math.max(0, Math.min(candidates.length - 1, Math.floor(randomValue * candidates.length)))
    return candidates[index].path
}
