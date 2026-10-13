import QtQuick
import QtTest
import "../../services/WallpaperCommand.js" as WallpaperCommand

TestCase {
    name: "WallpaperCommand"

    function test_allOutputsOmitOutputArgument() {
        const command = WallpaperCommand.image("/tmp/wallpaper.jpg", "*", "fade", 2)
        compare(JSON.stringify(command), JSON.stringify([
            "awww", "img", "/tmp/wallpaper.jpg", "--transition-type", "fade",
            "--transition-duration", "2"
        ]))
    }

    function test_emptyOutputUsesAllOutputs() {
        const command = WallpaperCommand.image("/tmp/wallpaper.jpg", "", "simple", 1)
        compare(JSON.stringify(command), JSON.stringify([
            "awww", "img", "/tmp/wallpaper.jpg", "--transition-type", "simple",
            "--transition-duration", "1"
        ]))
    }

    function test_namedOutputIsPassedThrough() {
        const command = WallpaperCommand.image("/tmp/wallpaper.jpg", "DP-1", "fade", 2)
        compare(JSON.stringify(command), JSON.stringify([
            "awww", "img", "/tmp/wallpaper.jpg", "-o", "DP-1", "--transition-type", "fade",
            "--transition-duration", "2"
        ]))
    }

    function test_themeSelectsWallpaperFromItsAccentGroup() {
        const wallpapers = [
            { path: "/kanagawa/images/a.jpg", themeName: "kanagawa" },
            { path: "/nord/images/b.jpg", themeName: "nord" },
            { path: "/ember/images/c.jpg", themeName: "ember" }
        ]
        compare(WallpaperCommand.randomWallpaper(wallpapers, "kanagawa", "", 0), "/kanagawa/images/a.jpg")
    }

    function test_themeWithoutMatchingGroupFallsBackToLibrary() {
        const wallpapers = [
            { path: "/kanagawa/images/blue.jpg", themeName: "kanagawa" },
            { path: "/ember/images/red.jpg", themeName: "ember" }
        ]
        compare(WallpaperCommand.randomWallpaper(wallpapers, "industrial", "/kanagawa/images/blue.jpg", 0), "/ember/images/red.jpg")
    }
}
