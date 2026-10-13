#!/usr/bin/env python3
"""Install Omarchy-format themes and render Dynamite's managed color outputs."""
from __future__ import annotations

import argparse
import colorsys
import configparser
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
import urllib.error
import urllib.request
from urllib.parse import urlsplit
from pathlib import Path
from PIL import Image, ImageOps

HOME = Path(os.environ.get("HOME", "~")).expanduser()
THEMES = HOME / ".config/omarchy/themes"
BACKGROUNDS = HOME / ".config/omarchy/backgrounds"
LEGACY_WALLPAPER_LIBRARY = HOME / "Pictures/Wallpapers"
WALLPAPER_LIBRARY = HOME / "Pictures/Themes"
STATE = HOME / ".local/state/dynamite/themes"
CONFIG = HOME / ".config"
ROOT = Path(__file__).resolve().parents[1]
ANSI = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
        "bright_black", "bright_red", "bright_green", "bright_yellow", "bright_blue",
        "bright_magenta", "bright_cyan", "bright_white")
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
ANSI_FALLBACK_KEYS = ("background", "red", "green", "yellow", "blue", "magenta", "cyan", "foreground",
                      "muted", "red", "green", "yellow", "blue", "magenta", "cyan", "bright_foreground")
ANSI_FALLBACK_COLORS = ("#15161E", "#F7768E", "#9ECE6A", "#E0AF68", "#7AA2F7", "#BB9AF7", "#7DCFFF", "#A9B1D6",
                        "#414868", "#FF7A93", "#B9F27C", "#FF9E64", "#7DA6FF", "#C0A0FF", "#0DB9D7", "#C0CAF5")
COLOR_KEYS = set(ANSI) | {f"color{i}" for i in range(16)} | {
    "accent", "selection", "muted", "background", "dark_background", "darker_background",
    "lighter_background", "foreground", "dark_foreground", "light_foreground", "bright_foreground", "cursor"
}
SAFE = re.compile(r"^[a-zA-Z0-9_][a-zA-Z0-9._+-]*$")
BASE = {
    "accent": "#7AA2F7", "accentContainer": "#354161", "onAccent": "#0F131E",
    "island": "#000000", "panel": "#14141D", "subpage": "#1A1B26", "card": "#1F212F",
    "chip": "#2B2F44", "raised": "#232636", "track": "#0A0A0E", "window": "#07080B",
    "sidebar": "#060709", "group": "#0F1016", "field": "#171822", "control": "#15161F",
    "switchOff": "#343A55", "knob": "#D0D7F8", "text": "#C0CAF5",
    "textSecondary": "#A9B1D6", "textMuted": "#565F89", "danger": "#F7768E",
}


def user_themes() -> Path:
    return THEMES


def parse_palette(path: Path) -> tuple[dict, dict]:
    raw = tomllib.loads((path / "colors.toml").read_text(encoding="utf-8"))
    required = ("background", "foreground", "accent")
    for key in required:
        if not isinstance(raw.get(key), str) or not HEX.fullmatch(raw[key]):
            raise ValueError(f"{path}/colors.toml: {key} must be a #RRGGBB color")
    for key in COLOR_KEYS.intersection(raw):
        if not isinstance(raw[key], str) or not HEX.fullmatch(raw[key]):
            raise ValueError(f"{path}/colors.toml: {key} must be a #RRGGBB color")
    for key in ANSI:
        index = ANSI.index(key)
        candidate = raw.get(key, raw.get(f"color{index}", raw.get(ANSI_FALLBACK_KEYS[index], ANSI_FALLBACK_COLORS[index])))
        if not isinstance(candidate, str) or not HEX.fullmatch(candidate):
            candidate = ANSI_FALLBACK_COLORS[index]
        raw[key] = candidate.upper()
    raw = {k: v.upper() if isinstance(v, str) and HEX.fullmatch(v) else v for k, v in raw.items()}
    bg, fg = raw["background"], raw["foreground"]
    accent = raw["accent"]
    mapped = dict(BASE)
    mapped.update({"accent": accent, "accentContainer": raw.get("selection", accent),
                   "onAccent": best_text_color(accent), "panel": bg,
                   "subpage": raw.get("dark_background", bg), "card": raw.get("lighter_background", bg),
                   "chip": raw.get("selection", bg), "raised": raw.get("lighter_background", bg),
                   "track": raw.get("darker_background", bg), "window": bg, "sidebar": bg,
                   "group": raw.get("dark_background", bg), "field": raw.get("dark_background", bg),
                   "control": raw.get("dark_background", bg), "switchOff": raw.get("muted", fg),
                   "knob": fg, "text": raw.get("bright_foreground", fg),
                   "textSecondary": fg, "textMuted": raw.get("muted", fg),
                   "danger": raw.get("red", raw.get("color1", BASE["danger"]))})
    if raw.get("mode") == "light":
        mapped.update({"island": bg})
    colors = [raw.get(f"color{i}", raw[ANSI[i]]) for i in range(16)]
    danger = mapped["danger"]
    preview = [accent, fg, danger]
    represented = {color.upper() for color in preview} | {bg.upper()}
    extra = next((color for color in colors if color.upper() not in represented), None)
    if extra:
        preview.append(extra)
    meta = {"name": path.name, "label": path.name.replace("-", " ").title(),
            "preview": preview, "colors": mapped,
            "ansi": colors, "mode": raw.get("mode", "dark")}
    return raw, meta


def best_text_color(value: str) -> str:
    def luminance(color: str) -> float:
        channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    lum = luminance(value)
    black = (lum + 0.05) / 0.05
    white = 1.05 / (lum + 0.05)
    return "#000000" if black >= white else "#FFFFFF"


def _color_luminance(value: str) -> float:
    channels = [int(value[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def _blend(first: str, second: str, amount: float) -> str:
    channels = [round(int(first[i:i + 2], 16) * (1 - amount) + int(second[i:i + 2], 16) * amount)
                for i in (1, 3, 5)]
    return "#" + "".join(f"{channel:02X}" for channel in channels)


def extract_image_palette(images: list[Path]) -> dict[str, str]:
    """Build a dark Omarchy palette from balanced samples of the chosen images."""
    if not images:
        raise ValueError("choose at least one image")
    samples = Image.new("RGB", (64, 64 * len(images)))
    for index, path in enumerate(images):
        try:
            with Image.open(path) as opened:
                tile = ImageOps.fit(opened.convert("RGB"), (64, 64))
                samples.paste(tile, (0, index * 64))
        except (OSError, ValueError) as error:
            raise ValueError(f"cannot read image {path}: {error}") from error

    quantized = samples.quantize(colors=64, method=Image.Quantize.MEDIANCUT)
    palette = quantized.getpalette() or []
    counts = quantized.getcolors(maxcolors=samples.width * samples.height) or []
    extracted = []
    seen = set()
    for count, palette_index in sorted(counts, reverse=True):
        offset = palette_index * 3
        color = "#" + "".join(f"{value:02X}" for value in palette[offset:offset + 3])
        if color not in seen:
            seen.add(color)
            extracted.append((count, color))
    if not extracted:
        raise ValueError("could not extract colors from the selected images")

    background = min((color for _, color in extracted), key=_color_luminance)
    foreground = best_text_color(background)
    accent_candidates = [color for _, color in extracted
                         if 0.08 < _color_luminance(color) < 0.82 and color != background]
    accent = (max(accent_candidates, key=lambda color: colorsys_saturation(color))
              if accent_candidates else "#7AA2F7")
    if colorsys_saturation(accent) < 0.12:
        accent = "#7AA2F7"

    semantic_hues = (0, 120, 60, 240, 300, 180)
    ansi = [background]
    for hue in semantic_hues:
        options = [color for _, color in extracted if color != background]
        if options:
            chosen = min(options, key=lambda color: hue_distance(color, hue))
        else:
            chosen = accent
        ansi.append(chosen)
    ansi.append(foreground)
    muted = _blend(background, foreground, 0.45)
    bright = []
    for color in ansi:
        bright.append(_blend(color, foreground, 0.35))
    ansi.extend(bright)

    values = {
        "background": background,
        "foreground": foreground,
        "accent": accent,
        "selection": accent,
        "muted": muted,
        "dark_background": background,
        "darker_background": background,
        "lighter_background": _blend(background, accent, 0.16),
        "bright_foreground": foreground,
        "cursor": foreground,
        "red": ansi[1], "green": ansi[2], "yellow": ansi[3],
        "blue": ansi[4], "magenta": ansi[5], "cyan": ansi[6],
    }
    values.update({f"color{index}": color for index, color in enumerate(ansi)})
    return values


def colors_toml(values: dict[str, str]) -> str:
    ordered = ("background", "foreground", "accent", "selection", "muted", "dark_background",
              "darker_background", "lighter_background", "bright_foreground", "cursor", "red", "green",
              "yellow", "blue", "magenta", "cyan") + tuple(f"color{i}" for i in range(16))
    return ('# Generated from the selected theme images; edit this file to refine the palette.\nmode = "dark"\n' + "".join(
        f'{key} = "{values[key]}"\n' for key in ordered))


def colorsys_saturation(value: str) -> float:
    red, green, blue = (int(value[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return colorsys.rgb_to_hsv(red, green, blue)[1]


def hue_distance(value: str, target: int) -> float:
    red, green, blue = (int(value[i:i + 2], 16) / 255 for i in (1, 3, 5))
    hue, saturation, _ = colorsys.rgb_to_hsv(red, green, blue)
    if saturation < 0.12:
        return 360
    distance = abs(hue * 360 - target)
    return min(distance, 360 - distance)


def create_theme(name: str, images: list[Path]) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    slug = safe_slug(slug)
    target = WALLPAPER_LIBRARY / slug
    if any(path.name.lower() == slug for path in theme_dirs()) or target.exists():
        raise ValueError(f"theme already exists: {slug}")
    normalized_images = [path.expanduser().resolve() for path in images]
    for path in normalized_images:
        if not path.is_file():
            raise ValueError(f"image does not exist: {path}")
        if path.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".avif"}:
            raise ValueError(f"unsupported image type: {path}")
    palette = extract_image_palette(normalized_images)
    WALLPAPER_LIBRARY.mkdir(parents=True, exist_ok=True)
    stage = WALLPAPER_LIBRARY / f".{slug}.staging-{os.getpid()}"
    if stage.exists():
        shutil.rmtree(stage)
    try:
        image_dir = stage / "images"
        image_dir.mkdir(parents=True)
        (stage / "colors.toml").write_text(colors_toml(palette), encoding="utf-8")
        copied_names = set()
        for source in normalized_images:
            destination = image_dir / source.name
            suffix = 1
            while destination.name.casefold() in copied_names or destination.exists():
                destination = image_dir / f"{source.stem}-{suffix}{source.suffix}"
                suffix += 1
            shutil.copy2(source, destination)
            copied_names.add(destination.name.casefold())
        parse_palette(stage)
        stage.rename(target)
    except Exception:
        if stage.exists():
            shutil.rmtree(stage)
        raise
    return slug


def prompt_theme_images() -> list[Path]:
    images = []
    while True:
        value = input("Image path (blank to finish): ").strip()
        if not value:
            break
        images.append(Path(value).expanduser())
    if not images:
        raise ValueError("choose at least one image")
    return images


def theme_dirs() -> list[Path]:
    local = ROOT / "themes"
    dirs = [p for p in local.iterdir() if p.is_dir() and (p / "colors.toml").is_file()] if local.exists() else []
    if THEMES.exists(): dirs.extend(p for p in THEMES.iterdir() if p.is_dir() and (p / "colors.toml").is_file())
    if WALLPAPER_LIBRARY.exists(): dirs.extend(p for p in WALLPAPER_LIBRARY.iterdir() if p.is_dir() and (p / "colors.toml").is_file())
    unique = {}
    for d in dirs: unique.setdefault(d.name.lower(), d)
    return list(unique.values())


def _move_preserving_collisions(source: Path, destination: Path) -> None:
    if source.is_dir() and not source.is_symlink():
        candidate = destination
        index = 1
        while candidate.is_symlink() or (candidate.exists() and not candidate.is_dir()):
            candidate = destination.with_name(f"{destination.name}-{index}")
            index += 1
        destination = candidate
        destination.mkdir(parents=True, exist_ok=True)
        for child in sorted(source.iterdir(), key=lambda path: path.name.casefold()):
            _move_preserving_collisions(child, destination / child.name)
        source.rmdir()
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    candidate = destination
    index = 1
    while candidate.exists() or candidate.is_symlink():
        candidate = destination.with_name(f"{destination.stem}-{index}{destination.suffix}")
        index += 1
    shutil.move(str(source), candidate)


def migrate_wallpaper_library() -> None:
    """Move the old wallpaper folders into Pictures/Themes without overwrites."""
    if not LEGACY_WALLPAPER_LIBRARY.is_dir():
        return
    WALLPAPER_LIBRARY.mkdir(parents=True, exist_ok=True)
    for child in sorted(LEGACY_WALLPAPER_LIBRARY.iterdir(), key=lambda path: path.name.casefold()):
        if child.is_dir() and (child / "images").is_dir():
            _move_preserving_collisions(child, WALLPAPER_LIBRARY / child.name)
    try:
        LEGACY_WALLPAPER_LIBRARY.rmdir()
    except OSError:
        pass


def theme_background_dir(slug: str) -> Path:
    return WALLPAPER_LIBRARY / slug / "images"


def ensure_theme_background_dir(slug: str) -> tuple[Path, list[Path]]:
    target = theme_background_dir(slug)
    missing = []
    current = target
    while current != HOME and not current.exists():
        missing.append(current)
        current = current.parent
    if current.exists() and not current.is_dir():
        raise ValueError(f"cannot create wallpaper folder below non-directory: {current}")
    created = []
    try:
        for directory in reversed(missing):
            directory.mkdir()
            created.append(directory)
    except OSError:
        for directory in reversed(created):
            try: directory.rmdir()
            except OSError: pass
        raise
    return target, created


def all_themes() -> list[dict]:
    result = []
    STATE.mkdir(parents=True, exist_ok=True)
    # Retire the legacy wallpaper-derived palette cache during migration.
    (STATE / "wallpaper.json").unlink(missing_ok=True)
    for path in sorted(theme_dirs(), key=lambda p: p.name.casefold()):
        try: _, item = parse_palette(path)
        except (OSError, ValueError, TypeError): continue
        item.update(item["colors"])
        result.append(item)
        atomic_json(STATE / f"{path.name}.json", {"name": path.name, **item["colors"],
                    "label": item["label"], "preview": item["preview"], "accent": item["colors"]["accent"],
                    "accentGroup": "neutral"})
    return result


def atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as f:
        json.dump(value, f, indent=2); f.write("\n"); tmp = Path(f.name)
    os.replace(tmp, path)


def backup_once(path: Path) -> None:
    backup = path.with_name(path.name + ".dynamite-backup")
    created = path.with_name(path.name + ".dynamite-created")
    if backup.exists() or created.exists(): return
    backup.parent.mkdir(parents=True, exist_ok=True)
    if path.exists(): shutil.copy2(path, backup)
    else: created.write_text("created by dynamite-theme\n", encoding="utf-8")


def write_managed(path: Path, content: str) -> None:
    backup_once(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def add_include(path: Path, include: str, marker: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    previous = path.read_text(encoding="utf-8") if path.exists() else ""
    if marker in previous: return
    backup_once(path)
    prefix = marker + "\n" + include + "\n"
    path.write_text(prefix + ("\n" + previous.lstrip() if previous.strip() else ""), encoding="utf-8")


def remove_include(path: Path, include: str, marker: str) -> None:
    if not path.is_file(): return
    lines = path.read_text(encoding="utf-8").splitlines()
    output = []
    index = 0
    changed = False
    while index < len(lines):
        if lines[index].strip() == marker and index + 1 < len(lines) and lines[index + 1].strip() == include:
            index += 2
            while index < len(lines) and not lines[index].strip(): index += 1
            changed = True
            continue
        output.append(lines[index])
        index += 1
    if changed:
        backup_once(path)
        path.write_text("\n".join(output).rstrip() + "\n", encoding="utf-8")


def select_kde_scheme(slug: str) -> None:
    path = CONFIG / "kdeglobals"
    previous = path.read_text(encoding="utf-8") if path.exists() else ""
    lines = previous.splitlines()
    output = []
    in_general = False
    inserted = False
    for line in lines:
        if line.startswith("["):
            if in_general and not inserted:
                output.append(f"ColorScheme=Dynamite-{slug}"); inserted = True
            in_general = line.strip() == "[General]"
        if in_general and line.startswith("ColorScheme="):
            if not inserted: output.append(f"ColorScheme=Dynamite-{slug}"); inserted = True
            continue
        output.append(line)
    if not inserted:
        if output and output[-1].strip(): output.append("")
        output += ["[General]", f"ColorScheme=Dynamite-{slug}"]
    backup_once(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(output).rstrip() + "\n", encoding="utf-8")


def set_active_setting(slug: str) -> None:
    settings = CONFIG / "dynamite/settings.json"
    try: data = json.loads(settings.read_text(encoding="utf-8"))
    except FileNotFoundError: data = {}
    except json.JSONDecodeError as error: raise ValueError("Dynamite settings JSON is invalid; refusing to replace it") from error
    if not isinstance(data, dict): raise ValueError("Dynamite settings JSON must contain an object")
    appearance = data.get("appearance")
    if not isinstance(appearance, dict): appearance = {}
    appearance["theme"] = slug
    data["appearance"] = appearance
    atomic_json(settings, data)


def firefox_profiles() -> list[Path]:
    roots = (HOME / ".mozilla/firefox", HOME / ".var/app/org.mozilla.firefox/.mozilla/firefox")
    profiles: list[Path] = []
    for root in roots:
        ini = root / "profiles.ini"
        if not ini.is_file(): continue
        parser = configparser.RawConfigParser()
        try: parser.read(ini, encoding="utf-8")
        except (OSError, configparser.Error): continue
        relative = []
        for section in parser.sections():
            values = parser[section]
            if section.startswith("Profile") and values.get("Default") == "1":
                relative.append(values.get("Path", ""))
            elif section.startswith("Install") and values.get("Default"):
                relative.append(values["Default"])
        if not relative:
            relative = [parser[section].get("Path", "") for section in parser.sections()
                        if section.startswith("Profile")][:1]
        for item in relative:
            if not item: continue
            profile = Path(item)
            if not profile.is_absolute(): profile = root / profile
            if profile.is_dir() and profile not in profiles: profiles.append(profile)
    return profiles


def write_firefox_theme(bg: str, fg: str, accent: str) -> None:
    css = (f"#navigator-toolbox, #urlbar-background, #searchbar {{ background-color: {bg} !important; }}\n"
           f"#navigator-toolbox, #urlbar, #searchbar {{ color: {fg} !important; }}\n"
           f".tabbrowser-tab[selected] .tab-background {{ background-color: {accent} !important; }}\n"
           f".tabbrowser-tab[selected] .tab-label {{ color: {best_text_color(accent)} !important; }}\n")
    profiles = firefox_profiles()
    if not profiles:
        write_managed(CONFIG / "dynamite/firefox/userChrome.css", css)
        return
    for profile in profiles:
        write_managed(profile / "chrome/userChrome.css", css)
        user_js = profile / "user.js"
        previous = user_js.read_text(encoding="utf-8") if user_js.exists() else ""
        pref = 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
        pref_pattern = r'(?m)^\s*user_pref\("toolkit\.legacyUserProfileCustomizations\.stylesheets"\s*,\s*(?:true|false)\s*\);\s*$'
        if re.search(pref_pattern, previous):
            updated = re.sub(pref_pattern, pref, previous)
        elif "toolkit.legacyUserProfileCustomizations.stylesheets" not in previous:
            updated = previous.rstrip() + ("\n" if previous.strip() else "") + pref + "\n"
        else:
            updated = previous
        if updated != previous:
            backup_once(user_js)
            user_js.parent.mkdir(parents=True, exist_ok=True)
            user_js.write_text(updated, encoding="utf-8")


def render(slug: str) -> None:
    source = next((p for p in theme_dirs() if p.name.lower() == slug.lower()), None)
    if source is None: raise ValueError(f"theme not installed: {slug}")
    raw, meta = parse_palette(source)
    colors, ansi = meta["colors"], meta["ansi"]
    bg, fg = raw["background"], raw["foreground"]
    lines = ["# Generated by dynamite-theme; edit the source theme colors.toml instead.",
             f"background {bg}", f"foreground {fg}", f"selection_background {raw.get('selection', colors['accent'])}",
             f"selection_foreground {colors['onAccent']}", f"cursor {raw.get('cursor', colors['accent'])}"]
    lines += [f"color{i} {c}" for i, c in enumerate(ansi)]
    kitty = "\n".join(lines) + "\n"
    foot = "\n".join(["# Generated by dynamite-theme", "[colors]", f"background={bg[1:]}", f"foreground={fg[1:]}",
                       f"selection-background={colors['accent'][1:]}", f"selection-foreground={colors['onAccent'][1:]}"] +
                      [f"regular{i}={ansi[i][1:]}" for i in range(8)] + [f"bright{i}={ansi[i+8][1:]}" for i in range(8)])
    write_managed(CONFIG / "fish/conf.d/dynamite-theme.fish", f"# Generated by dynamite-theme\nset -gx fish_color_command '{ansi[4]}'\nset -gx fish_color_error '{colors['danger']}'\nset -gx fish_color_param '{fg}'\nset -gx fish_color_quote '{ansi[2]}'\n")
    # Reuse the previous Dynamite terminal output paths so existing includes
    # cannot keep an obsolete wallpaper palette ahead of the managed colors.
    write_managed(CONFIG / "kitty/current-theme.conf", kitty)
    write_managed(CONFIG / "foot/colors.ini", foot)
    # The existing configs include these managed outputs. Remove the older
    # wallpaper-generated include that followed them and overrode their colors.
    remove_include(CONFIG / "kitty/kitty.conf", "include dynamite-theme.conf", "# Dynamite managed theme include")
    remove_include(CONFIG / "foot/foot.ini", "include=~/.config/foot/dynamite-theme.ini", "# Dynamite managed theme include")
    if shutil.which("pkill"):
        subprocess.run(["pkill", "-USR1", "kitty"], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    gtk3_css = (f"@define-color accent_color {colors['accent']};\n"
                f"@define-color accent_bg_color {colors['accent']};\n"
                f"@define-color accent_fg_color {colors['onAccent']};\n"
                f"@define-color window_bg_color {colors['panel']};\n"
                f"@define-color window_fg_color {colors['text']};\n"
                f"@define-color headerbar_bg_color {colors['panel']};\n"
                f"@define-color headerbar_fg_color {colors['text']};\n"
                f"@define-color popover_bg_color {colors['card']};\n"
                f"@define-color popover_fg_color {colors['text']};\n"
                f"@define-color view_bg_color {colors['window']};\n"
                f"@define-color view_fg_color {colors['text']};\n"
                f"@define-color card_bg_color {colors['card']};\n"
                f"@define-color card_fg_color {colors['text']};\n"
                f"@define-color sidebar_bg_color {colors['sidebar']};\n"
                f"@define-color sidebar_fg_color {colors['text']};\n"
                f"@define-color theme_selected_bg_color {colors['accent']};\n"
                f"@define-color theme_selected_fg_color {colors['onAccent']};\n"
                f"window, dialog, headerbar {{ background-color: {colors['panel']}; color: {colors['text']}; }}\n"
                f"button.suggested-action, button:checked {{ background-color: {colors['accent']}; color: {colors['onAccent']}; }}\n")
    gtk4_css = (":root {\n"
                f"  --accent-bg-color: {colors['accent']};\n  --accent-fg-color: {colors['onAccent']};\n  --accent-color: {colors['accent']};\n"
                f"  --window-bg-color: {colors['panel']};\n  --window-fg-color: {colors['text']};\n"
                f"  --headerbar-bg-color: {colors['panel']};\n  --headerbar-fg-color: {colors['text']};\n"
                f"  --view-bg-color: {colors['window']};\n  --view-fg-color: {colors['text']};\n"
                f"  --sidebar-bg-color: {colors['sidebar']};\n  --sidebar-fg-color: {colors['text']};\n"
                f"  --popover-bg-color: {colors['card']};\n  --popover-fg-color: {colors['text']};\n"
                f"  --card-bg-color: {colors['card']};\n  --card-fg-color: {colors['text']};\n"
                "}\n")
    write_managed(CONFIG / "gtk-3.0/dynamite-theme.css", gtk3_css)
    write_managed(CONFIG / "gtk-4.0/dynamite-theme.css", gtk4_css)
    # GTK requires imports before style rules. Take ownership of the root user
    # stylesheets after backing up their previous wallpaper-generated contents.
    write_managed(CONFIG / "gtk-3.0/gtk.css", '@import url("dynamite-theme.css");')
    write_managed(CONFIG / "gtk-4.0/gtk.css", '@import url("dynamite-theme.css");')
    def kde_colors(section: str, background: str, foreground: str) -> str:
        return (f"[Colors:{section}]\nBackgroundNormal={rgb(background)}\n"
                f"BackgroundAlternate={rgb(colors['card'])}\nForegroundNormal={rgb(foreground)}\n"
                f"ForegroundInactive={rgb(colors['textSecondary'])}\nForegroundLink={rgb(colors['accent'])}\n"
                f"ForegroundVisited={rgb(ansi[5])}\nForegroundNegative={rgb(colors['danger'])}\n"
                f"ForegroundNeutral={rgb(ansi[3])}\nForegroundPositive={rgb(ansi[2])}\n"
                f"DecorationFocus={rgb(colors['accent'])}\nDecorationHover={rgb(colors['accent'])}\n\n")
    kde = (f"[General]\nName=Dynamite {meta['label']}\n\n" +
           kde_colors("View", bg, fg) + kde_colors("Window", bg, fg) +
           kde_colors("Button", colors["control"], fg) +
           kde_colors("Selection", colors["accent"], colors["onAccent"]) +
           kde_colors("Tooltip", colors["card"], fg))
    write_managed(HOME / f".local/share/color-schemes/Dynamite-{slug}.colors", kde)
    select_kde_scheme(slug)
    write_managed(CONFIG / "fuzzel/dynamite-theme.ini", f"[colors]\nbackground={bg[1:]}ff\ntext={fg[1:]}ff\nprompt={colors['accent'][1:]}ff\nselection={colors['accent'][1:]}ff\nselection-text={colors['onAccent'][1:]}ff\nborder={colors['accent'][1:]}ff\n")
    add_include(CONFIG / "fuzzel/fuzzel.ini", f"include={CONFIG / 'fuzzel/dynamite-theme.ini'}", "# Dynamite managed theme include")
    write_firefox_theme(bg, fg, colors["accent"])
    write_managed(CONFIG / "dynamite/steam/theme.css", f":root {{ --dynamite-bg: {bg}; --dynamite-fg: {fg}; --dynamite-accent: {colors['accent']}; }}\n")
    atomic_json(STATE / f"{slug}.json", {"name": slug, "label": meta["label"], "preview": meta["preview"],
        "accentGroup": "neutral", "accent": colors["accent"], **colors})
    atomic_json(CONFIG / "omarchy/current-theme.json", {"theme": slug})
    notify_index()


def rgb(value: str) -> str:
    v = value.lstrip("#"); return ",".join(str(int(v[i:i+2], 16)) for i in (0, 2, 4))


def safe_slug(value: str) -> str:
    slug = value.lower()
    if not SAFE.fullmatch(slug): raise ValueError("invalid theme name (allowed: letters, digits, ., _, +, -)")
    if slug == "wallpaper": raise ValueError("wallpaper is a retired palette name reserved for migration")
    return slug


def notify_index() -> None:
    THEMES.mkdir(parents=True, exist_ok=True)
    (THEMES / ".dynamite-index").write_text(str(time.time_ns()), encoding="utf-8")


def source_url(source: str) -> tuple[str, str | None]:
    if source.startswith(("http://", "git@")):
        raise ValueError("theme repository URLs must use public HTTPS")
    if source.startswith("https://"):
        parsed = urlsplit(source)
        if parsed.username or parsed.password or not parsed.hostname:
            raise ValueError("theme URL must not contain credentials")
        return source, None
    # Resolve names against Omarchy's published registry. The CDN is primary;
    # the marketplace's public GitHub snapshot keeps name installs available
    # during CDN outages.
    catalog_urls = ("https://cdn.themes.omarchy.org/v1/catalog.json",
                    "https://raw.githubusercontent.com/omacom/omarchy-theme-marketplace/master/data/catalog.json")
    catalog = None
    for url in catalog_urls:
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "dynamite-theme/1.0"})
            with urllib.request.urlopen(request, timeout=15) as response:
                catalog = json.load(response)
            break
        except (OSError, ValueError, urllib.error.URLError):
            continue
    if not isinstance(catalog, dict) or not isinstance(catalog.get("themes"), list):
        raise ValueError("could not load the public Omarchy theme catalog")
    needle = re.sub(r"[^a-z0-9]+", "-", source.lower()).strip("-")
    for item in catalog["themes"]:
        if not isinstance(item, dict): continue
        candidates = (item.get("slug", ""), item.get("name", ""))
        if any(re.sub(r"[^a-z0-9]+", "-", str(value).lower()).strip("-") == needle for value in candidates):
            repo = item.get("repo")
            if isinstance(repo, str) and repo.startswith("https://"):
                slug = item.get("slug")
                return repo, slug if isinstance(slug, str) else None
    raise ValueError(f"theme not found in Omarchy theme gallery: {source}")


def install(source: str) -> str:
    url, catalog_slug = source_url(source)
    slug = safe_slug(catalog_slug or url.rstrip("/").split("/")[-1].removesuffix(".git"))
    if catalog_slug is None:
        if slug.startswith("omarchy-"): slug = slug[len("omarchy-"):]
        if slug.endswith("-theme"): slug = slug[:-len("-theme")]
    target = THEMES / slug
    if target.exists(): raise ValueError(f"theme already installed: {slug}")
    if any(path.name.lower() == slug for path in theme_dirs()): raise ValueError(f"theme already exists: {slug}")
    THEMES.mkdir(parents=True, exist_ok=True)
    stage = THEMES / f".{slug}.staging"
    if stage.exists(): shutil.rmtree(stage)
    created_background_dirs: list[Path] = []
    target_created = False
    try:
        subprocess.run(["git", "-c", "credential.helper=", "clone", "--depth", "1", "--filter=blob:none", "--sparse", url, str(stage)],
                       check=True, env={**os.environ, "GIT_TERMINAL_PROMPT": "0", "GIT_ASKPASS": "/usr/bin/false"})
        subprocess.run(["git", "-C", str(stage), "sparse-checkout", "set", "--no-cone", "/colors.toml", "/backgrounds/"], check=True)
        if not (stage / "colors.toml").is_file(): raise ValueError("repository has no root colors.toml")
        parse_palette(stage)
        _, created_background_dirs = ensure_theme_background_dir(slug)
        stage.rename(target)
        target_created = True
    except Exception:
        if stage.exists(): shutil.rmtree(stage)
        if target_created and target.exists(): shutil.rmtree(target)
        for directory in reversed(created_background_dirs):
            try: directory.rmdir()
            except OSError: pass
        raise
    return slug


def add_background(slug: str, image: Path) -> Path:
    slug = safe_slug(slug)
    if not any(p.name.lower() == slug for p in theme_dirs()): raise ValueError(f"theme not installed: {slug}")
    if not image.is_file(): raise ValueError(f"background image does not exist: {image}")
    if image.suffix.lower() not in {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".avif"}:
        raise ValueError("unsupported background image type")
    destination = theme_background_dir(slug) / image.name
    destination.parent.mkdir(parents=True, exist_ok=True)
    suffix = 1
    while destination.exists():
        destination = destination.with_name(f"{image.stem}-{suffix}{image.suffix}")
        suffix += 1
    shutil.move(str(image), destination)
    return destination


def list_themes() -> None:
    active = ""
    try: active = json.loads((CONFIG / "omarchy/current-theme.json").read_text()).get("theme", "")
    except (OSError, json.JSONDecodeError): pass
    for item in all_themes(): print(("* " if item["name"] == active else "  ") + item["name"])


def main() -> int:
    p = argparse.ArgumentParser(prog="dynamite-theme")
    sub = p.add_subparsers(dest="action", required=True)
    sub.add_parser("list")
    c = sub.add_parser("create", help="create a theme from selected images")
    c.add_argument("name", help="theme name; spaces are converted to hyphens")
    i = sub.add_parser("install"); i.add_argument("source")
    r = sub.add_parser("remove"); r.add_argument("slugs", nargs="+", metavar="SLUG")
    u = sub.add_parser("update"); u.add_argument("slug", nargs="?")
    a = sub.add_parser("apply"); a.add_argument("slug"); a.add_argument("--no-settings", action="store_true")
    b = sub.add_parser("add-background"); b.add_argument("slug"); b.add_argument("image", type=Path)
    args = p.parse_args()
    try:
        migrate_wallpaper_library()
        if args.action == "install": print(install(args.source))
        elif args.action == "create":
            slug = create_theme(args.name, prompt_theme_images())
            print(f"created {slug} at {WALLPAPER_LIBRARY / slug}")
            notify_index()
        elif args.action == "list": list_themes()
        elif args.action == "apply":
            slug = "nord" if args.slug.lower() == "wallpaper" else safe_slug(args.slug)
            render(slug)
            if not args.no_settings: set_active_setting(slug)
        elif args.action == "add-background":
            print(add_background(args.slug, args.image))
        elif args.action == "remove":
            slugs = list(dict.fromkeys(safe_slug(value) for value in args.slugs))
            targets = []
            for slug in slugs:
                installed = THEMES / slug
                created = WALLPAPER_LIBRARY / slug
                if installed.is_dir():
                    targets.append((slug, installed, "installed"))
                elif (created / "colors.toml").is_file():
                    targets.append((slug, created, "created"))
                else:
                    bundled = ROOT / "themes" / slug
                    if bundled.is_dir():
                        detail = "the protected fallback" if slug == "nord" else "bundled with Dynamite"
                        raise ValueError(f"{slug} is {detail}, not installed under {THEMES}; it cannot be removed with this command")
                    raise ValueError(f"not an installed theme: {slug}")
            active = ""
            try: active = json.loads((CONFIG / "omarchy/current-theme.json").read_text()).get("theme", "")
            except (OSError, json.JSONDecodeError): pass
            if active in slugs:
                settings = CONFIG / "dynamite/settings.json"
                if settings.exists():
                    try: current_settings = json.loads(settings.read_text(encoding="utf-8"))
                    except json.JSONDecodeError as error: raise ValueError("Dynamite settings JSON is invalid; refusing active-theme removal") from error
                    if not isinstance(current_settings, dict): raise ValueError("Dynamite settings JSON must contain an object")
            for slug, target, kind in targets:
                if kind == "installed":
                    shutil.rmtree(target)
                else:
                    (target / "colors.toml").unlink()
                    for directory in (target / "backgrounds", target):
                        try: directory.rmdir()
                        except OSError: pass
                (STATE / f"{slug}.json").unlink(missing_ok=True)
                print(f"removed {slug}")
            if active in slugs:
                render("nord")
                set_active_setting("nord")
            notify_index()
        elif args.action == "update":
            targets = [THEMES / safe_slug(args.slug)] if args.slug else [x for x in THEMES.iterdir() if x.is_dir()]
            for target in targets:
                if not target.exists() or not (target / ".git").exists(): continue
                subprocess.run(["git", "-C", str(target), "fetch", "--depth", "1", "origin"], check=True)
                candidate = subprocess.check_output(["git", "-C", str(target), "show", "FETCH_HEAD:colors.toml"], text=True)
                with tempfile.TemporaryDirectory(prefix="dynamite-theme-validate-") as temp:
                    check = Path(temp); (check / "colors.toml").write_text(candidate, encoding="utf-8")
                    parse_palette(check)
                subprocess.run(["git", "-C", str(target), "pull", "--ff-only"], check=True)
                parse_palette(target)
                try: active = json.loads((CONFIG / "omarchy/current-theme.json").read_text()).get("theme", "")
                except (OSError, json.JSONDecodeError): active = ""
                if active == target.name: render(target.name)
            notify_index()
        if args.action == "install": notify_index()
    except (OSError, ValueError, subprocess.CalledProcessError, urllib.error.URLError) as e:
        print(f"dynamite-theme: {e}", file=sys.stderr); return 1
    return 0


if __name__ == "__main__": raise SystemExit(main())
