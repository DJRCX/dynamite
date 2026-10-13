#!/usr/bin/env python3
"""Index Omarchy theme packages and their shipped or user-added backgrounds."""

from __future__ import annotations

import argparse
import colorsys
import json
import os
from pathlib import Path


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".avif"}
GROUPS_PATH = Path(__file__).resolve().parent.parent / "themes" / "accent-groups.json"


def read_groups(path: Path) -> list[dict]:
    groups = json.loads(path.read_text(encoding="utf-8"))["groups"]
    if not groups or any("id" not in group or "color" not in group for group in groups):
        raise ValueError(f"Invalid accent group index: {path}")
    return groups


def image_paths(root: Path):
    for current, directories, filenames in os.walk(root):
        directories[:] = sorted(name for name in directories if not name.startswith("."))
        for filename in sorted(filenames):
            path = Path(current) / filename
            if path.suffix.lower() in IMAGE_EXTENSIONS and path.is_file():
                yield path


def group_for_color(value: str, groups: list[dict]) -> str:
    value = value.lstrip("#")
    red, green, blue = (int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hue, saturation, _ = colorsys.rgb_to_hsv(red, green, blue)
    neutral = next((group for group in groups if group["id"] == "neutral"), groups[0])
    if saturation < neutral.get("saturationMax", 0.18):
        return neutral["id"]
    degrees = hue * 360
    for group in groups:
        if group["id"] == "neutral":
            continue
        if any(start <= degrees < end for start, end in group.get("hueRanges", [])):
            return group["id"]
    return neutral["id"]


def catalog(wallpaper_dir: Path, groups: list[dict]) -> dict:
    # Omarchy colors.toml is the sole palette source. Package backgrounds stay
    # in their repository; user images and old wallpaper-library files remain
    # separate so removing a theme cannot erase a personal background.
    from theme_manager import BACKGROUNDS, WALLPAPER_LIBRARY, all_themes, theme_dirs

    themes = all_themes()
    by_name = {theme["name"]: theme for theme in themes}
    wallpapers = []
    seen_paths: set[str] = set()

    def add_images(theme_name: str, directory: Path) -> None:
        theme = by_name.get(theme_name)
        if not theme or not directory.exists():
            return
        accent = theme["accent"]
        for path in image_paths(directory):
            resolved = str(path.resolve())
            if resolved in seen_paths:
                continue
            seen_paths.add(resolved)
            wallpapers.append({
                "path": str(path), "url": path.resolve().as_uri(), "name": path.name,
                "themeName": theme_name, "accentGroup": group_for_color(accent, groups),
                "accent": accent,
            })

    for package in theme_dirs():
        add_images(package.name, package / "backgrounds")
        add_images(package.name, BACKGROUNDS / package.name)
        add_images(package.name, WALLPAPER_LIBRARY / package.name / "images")

    # Also retain compatibility with a user-configured wallpaper library.
    for library in dict.fromkeys((wallpaper_dir, WALLPAPER_LIBRARY)):
        if library.exists():
            for path in image_paths(library):
                try:
                    relative = path.relative_to(library)
                    if len(relative.parts) < 3 or relative.parts[1] != "images":
                        continue
                    add_images(relative.parts[0], path.parent)
                except (OSError, ValueError):
                    continue

    return {
        "accentGroups": groups,
        "themes": sorted(themes, key=lambda theme: theme["name"].casefold()),
        "wallpapers": sorted(wallpapers, key=lambda item: (item["themeName"].casefold(), item["name"].casefold())),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("index",))
    parser.add_argument("--groups", type=Path, default=GROUPS_PATH)
    parser.add_argument("--wallpapers", type=Path, required=True)
    args = parser.parse_args()
    from theme_manager import migrate_wallpaper_library
    migrate_wallpaper_library()
    result = catalog(args.wallpapers, read_groups(args.groups))
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
