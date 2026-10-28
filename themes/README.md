# Dynamite themes

Dynamite uses Omarchy theme packages. Bundled packages live in
`themes/<slug>/colors.toml`, installed public repositories live in
`~/.config/omarchy/themes/<slug>`, and user-created packages live in
`~/Pictures/Themes/<slug>/`. User-created packages include `colors.toml` and
an `images/` folder. Installed themes use `~/Pictures/Themes/<slug>/images/`
for user-added and Wallhaven backgrounds; `dynamite-theme add-background
<slug> <image>` moves the image there. Theme package backgrounds stay in their
repository. Existing theme folders under `~/Pictures/Wallpapers/` are moved to
`~/Pictures/Themes/` on the next theme command or picker index, preserving
same-name files with a numeric suffix. Existing images in
`~/.config/omarchy/backgrounds/<slug>` and any separately configured wallpaper
library remain indexed in place. Removing a theme never deletes user images.
Installed repositories are treated as data: Dynamite reads `colors.toml` and
image files only.

Nord is the only bundled theme and the protected fallback. Its palette and four
wallpapers are from [Omarchy v4.0.2](https://github.com/basecamp/omarchy/tree/v4.0.2/themes/nord);
the featured `0-black-moon.jpg` is the initial desktop wallpaper, and all four
images are available in the wallpaper picker and when switching to Nord.

Install the command with `./install.sh`, then manage packages with:

```sh
dynamite-theme install "Theme Name"
dynamite-theme install https://github.com/owner/omarchy-example-theme
dynamite-theme create "My New Theme"
dynamite-theme list
dynamite-theme update
dynamite-theme remove example another-example
```

Gallery names resolve against the public Omarchy theme gallery. Theme packages
must provide a flat `colors.toml` with `background`, `foreground`, `accent`,
and any Omarchy named or numbered ANSI colors. Explicit `color0`–`color15`
values take precedence; missing ANSI slots are derived from named semantic
colors or a bundled fallback palette. Dynamite also understands Omarchy's
optional `mode`, `selection`, muted/background/foreground steps, and cursor
values.

`create` asks for one or more local image paths; submit a blank path when
finished. It copies those images into `~/Pictures/Themes/<slug>/images/`,
extracts a dark palette with Pillow, and writes an editable Omarchy
`colors.toml`. The new theme is listed and can be applied with
`dynamite-theme apply <slug>`; creation does not change the active theme.

`remove` accepts one or more slugs and validates the whole request before it
removes installed repositories from `~/.config/omarchy/themes` or a
user-created theme's `colors.toml`. Images under `~/Pictures/Themes` are
preserved. Nord is kept in the Dynamite checkout as the protected fallback and
cannot be removed.

The source palette is the only color authority. The manager renders a Quickshell
cache at `~/.local/state/dynamite/themes/<slug>.json` and the dedicated app
outputs below. CLI selection updates `~/.config/dynamite/settings.json`; the
selected slug is mirrored in `~/.config/omarchy/current-theme.json`.

The Appearance settings editor stores per-theme color overrides in the
`appearance.colorOverrides` setting in Dynamite's settings JSON. It does not
modify Omarchy theme repositories or bundled `colors.toml` files. The theme
manager validates those overrides and applies them to the Quickshell palette,
terminal ANSI colors, and supported application outputs. Removing an override
restores that role from the selected theme package.

- `~/.config/fish/conf.d/dynamite-theme.fish`
- `~/.config/kitty/current-theme.conf`
- `~/.config/kitty/kitty.conf` (adds a managed include)
- `~/.config/foot/colors.ini`
- `~/.config/foot/foot.ini` (adds a managed include)
- `~/.config/gtk-3.0/dynamite-theme.css` and `~/.config/gtk-4.0/dynamite-theme.css`
- `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css` (add managed imports)
- `~/.local/share/color-schemes/Dynamite-<slug>.colors`
- `~/.config/kdeglobals` (selects the generated KDE color scheme)
- `~/.config/fuzzel/dynamite-theme.ini`
- `~/.config/fuzzel/fuzzel.ini` (adds a managed include)
- `chrome/userChrome.css` and `user.js` in the detected default Firefox profile (or `~/.config/dynamite/firefox/userChrome.css` when no profile exists)
- `~/.config/dynamite/steam/theme.css`
- `~/.config/omarchy/current-theme.json`
- `~/.config/omarchy/themes/.dynamite-index` (picker refresh signal)

If a managed output already exists, the manager preserves its first pre-theme
version beside it as `.dynamite-backup`. For destinations it creates, a
`.dynamite-created` marker records that there was no prior file to restore.
Switching themes updates the generated files; running apps that support reload
can pick up changes, while other apps use the new colors on next launch.
Wallpaper changes never regenerate a palette.
Quickshell regenerates these app outputs from the persisted selected theme
after its settings have loaded at startup, so a previous session's generated
palette does not remain active after changing the saved theme while the shell
was stopped.
