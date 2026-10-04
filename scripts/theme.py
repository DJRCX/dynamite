#!/usr/bin/env python3
import os
import sys
import glob
import json
import time
import random
import shutil
import urllib.request
import urllib.parse
from PIL import Image
import colorsys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(BASE_DIR, "config.json")
COLORS_PATH = os.path.join(BASE_DIR, "colors.json")
CACHE_DIR = os.path.expanduser("~/.cache/simple-bar")
THUMB_DIR = os.path.join(CACHE_DIR, "wallpapers")
DEFAULT_WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")

os.makedirs(CACHE_DIR, exist_ok=True)
os.makedirs(THUMB_DIR, exist_ok=True)

def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_config(cfg):
    try:
        with open(CONFIG_PATH, "w") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        sys.stderr.write(f"Failed to save config: {e}\n")

def ensure_daemon():
    """Ensure awww-daemon is running via systemd or direct spawn."""
    res = os.system("pgrep -x awww-daemon >/dev/null 2>&1")
    if res != 0:
        s_res = os.system("systemctl --user start awww-daemon.service >/dev/null 2>&1")
        if s_res != 0:
            os.system("setsid awww-daemon >/dev/null 2>&1 &")
        time.sleep(0.4)

def get_current_wallpaper():
    """Query awww to find currently displayed wallpaper."""
    try:
        import subprocess
        res = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=2)
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                if "currently displaying: image:" in line:
                    path = line.split("currently displaying: image:")[-1].strip()
                    if os.path.exists(path):
                        return path
    except Exception:
        pass
    
    cfg = load_config()
    wp = cfg.get("wallpaper")
    if wp and os.path.exists(wp):
        return wp
    return ""

def get_random_transition():
    """Generate a randomized transition parameter list for awww."""
    transitions = [
        ("wipe", ["--transition-type", "wipe", "--transition-angle", str(random.choice([30, 45, 60, 120, 135, 210, 225, 315]))]),
        ("fade", ["--transition-type", "fade"]),
        ("grow", ["--transition-type", "grow", "--transition-pos", random.choice(["center", "top", "bottom", "left", "right", "top-left", "bottom-right"])]),
        ("wave", ["--transition-type", "wave", "--transition-angle", str(random.choice([45, 135, 225, 315]))]),
        ("outer", ["--transition-type", "outer"]),
        ("left", ["--transition-type", "left"]),
        ("right", ["--transition-type", "right"]),
        ("top", ["--transition-type", "top"]),
        ("bottom", ["--transition-type", "bottom"]),
    ]
    name, args = random.choice(transitions)
    full_args = list(args) + ["--transition-duration", "1.2", "--transition-fps", "60"]
    return full_args

def rgb_to_hex(rgb):
    return "#{:02x}{:02x}{:02x}".format(max(0, min(255, int(rgb[0]))),
                                         max(0, min(255, int(rgb[1]))),
                                         max(0, min(255, int(rgb[2]))))

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip("#")
    if len(hex_str) == 6:
        return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))
    return (255, 255, 255)

def adjust_lightness(rgb, factor):
    r, g, b = [x / 255.0 for x in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    v = max(0.0, min(1.0, v * factor))
    nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
    return (int(nr * 255), int(ng * 255), int(nb * 255))

def blend_colors(fg_rgb, bg_rgb, alpha):
    return tuple(int(fg_rgb[i] * alpha + bg_rgb[i] * (1.0 - alpha)) for i in range(3))

def extract_palette(image_path, mode="pitch_black", custom_accent=None):
    """
    Extract harmonious color palette from an image using Pillow (PIL).
    Returns a dictionary of semantic tokens and swatch list.
    """
    if not image_path or not os.path.exists(image_path):
        # Fallback to default pitch black palette
        return {
            "bg": "#000000",
            "bgTranslucent": "#fa000000",
            "surface": "#0a0a0a",
            "surfaceHover": "#161616",
            "surfaceActive": "#222222",
            "border": "#1f1f1f",
            "borderLight": "#2c2c2c",
            "borderAccent": "#304060",
            "text": "#f0f2fb",
            "textMuted": "#7a7d90",
            "accent": "#89b4fa",
            "accentSurface": "#141c2b",
            "accentHover": "#b4befe",
            "secondary": "#cba6f7",
            "palette": ["#89b4fa", "#cba6f7", "#f38ba8", "#a6e3a1", "#fab387", "#94e2d5"]
        }

    try:
        img = Image.open(image_path).convert("RGB")
        img.thumbnail((150, 150), Image.Resampling.LANCZOS)
        paletted = img.quantize(colors=24, method=Image.Quantize.FASTOCTREE)
        raw_palette = paletted.getpalette()[:72]
        unique_colors = []
        for i in range(0, len(raw_palette), 3):
            c = (raw_palette[i], raw_palette[i+1], raw_palette[i+2])
            if c not in unique_colors:
                unique_colors.append(c)

        scored_accents = []
        for c in unique_colors:
            r, g, b = [x / 255.0 for x in c]
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            # Filter out near-black or washed-out desaturated tones
            if v < 0.22 or (s < 0.15 and v > 0.85):
                continue
            # Score: prioritize vibrant saturation and pleasant luminance
            score = (s ** 1.3) * (v ** 0.5) * (1.0 - abs(v - 0.65) * 0.5)
            scored_accents.append((score, c, (h, s, v)))

        scored_accents.sort(reverse=True, key=lambda x: x[0])
        
        # Build 6 distinct swatches for the swatch bar
        swatches = []
        for item in scored_accents:
            hex_c = rgb_to_hex(item[1])
            # Ensure swatch isn't too close to existing swatches
            if not any(abs(item[2][0] - s_h) < 0.08 for s_h in [colorsys.rgb_to_hsv(*[x/255.0 for x in hex_to_rgb(s)])[0] for s in swatches]):
                swatches.append(hex_c)
            if len(swatches) >= 6:
                break
        
        if len(swatches) < 6:
            for item in scored_accents:
                hex_c = rgb_to_hex(item[1])
                if hex_c not in swatches:
                    swatches.append(hex_c)
                if len(swatches) >= 6:
                    break

        if not swatches:
            swatches = ["#89b4fa", "#cba6f7", "#f38ba8", "#a6e3a1", "#fab387", "#94e2d5"]

        primary_rgb = hex_to_rgb(custom_accent) if custom_accent else (scored_accents[0][1] if scored_accents else hex_to_rgb("#89b4fa"))
        primary_hex = rgb_to_hex(primary_rgb)

        # Lighter interactive accent
        accent_hover_rgb = adjust_lightness(primary_rgb, 1.25)
        accent_hover = rgb_to_hex(accent_hover_rgb)

        # Container tinted surface (15% accent over dark background)
        base_dark = (0, 0, 0)
        accent_surface_rgb = blend_colors(primary_rgb, base_dark, 0.16)
        accent_surface = rgb_to_hex(accent_surface_rgb)

        # Border accent (35% accent blend)
        border_accent = rgb_to_hex(blend_colors(primary_rgb, base_dark, 0.35))

        # Secondary accent (take next highest distinct swatch)
        secondary_hex = swatches[1] if len(swatches) > 1 and swatches[1] != primary_hex else (swatches[0] if swatches[0] != primary_hex else "#cba6f7")

        if mode == "tinted":
            # Deep Material Dark mode with subtle wallpaper tint
            surface_rgb = blend_colors(primary_rgb, (10, 10, 12), 0.08)
            surface_hover_rgb = blend_colors(primary_rgb, (22, 22, 26), 0.10)
            surface_active_rgb = blend_colors(primary_rgb, (32, 32, 38), 0.12)
            border_rgb = blend_colors(primary_rgb, (28, 28, 34), 0.15)
            border_light_rgb = blend_colors(primary_rgb, (42, 42, 50), 0.18)
            bg = "#000000"
            surface = rgb_to_hex(surface_rgb)
            surface_hover = rgb_to_hex(surface_hover_rgb)
            surface_active = rgb_to_hex(surface_active_rgb)
            border = rgb_to_hex(border_rgb)
            border_light = rgb_to_hex(border_light_rgb)
        else:
            # Pure Pitch Black Aesthetic with wallpaper accent
            bg = "#000000"
            surface = "#0a0a0a"
            surface_hover = "#161616"
            surface_active = "#222222"
            border = "#1f1f1f"
            border_light = "#2c2c2c"

        tokens = {
            "bg": bg,
            "bgTranslucent": "#fa000000",
            "surface": surface,
            "surfaceHover": surface_hover,
            "surfaceActive": surface_active,
            "border": border,
            "borderLight": border_light,
            "borderAccent": border_accent,
            "text": "#f0f2fb",
            "textMuted": "#7a7d90",
            "accent": primary_hex,
            "accentSurface": accent_surface,
            "accentHover": accent_hover,
            "secondary": secondary_hex,
            "palette": swatches
        }
        return tokens
    except Exception as e:
        sys.stderr.write(f"Extraction error: {e}\n")
        return extract_palette("", mode)

def export_terminal_themes(tokens, wallpaper_path=""):
    """Generate Kitty and Foot dynamic themes and notify running instances."""
    accent = tokens.get("accent", "#89b4fa")
    accent_hover = tokens.get("accentHover", "#b4befe")
    secondary = tokens.get("secondary", "#cba6f7")
    bg = tokens.get("bg", "#000000")
    surface = tokens.get("surface", "#0a0a0a")
    border = tokens.get("border", "#1f1f1f")
    border_light = tokens.get("borderLight", "#2c2c2c")
    fg = tokens.get("text", "#f0f2fb")
    fg_muted = tokens.get("textMuted", "#7a7d90")
    swatches = tokens.get("palette", [])

    # Map swatches to ANSI hues or fallbacks
    ansi_defaults = {
        "red": "#f38ba8",
        "green": "#a6e3a1",
        "yellow": "#f9e2af",
        "blue": "#89b4fa",
        "magenta": "#cba6f7",
        "cyan": "#94e2d5",
    }
    ansi_map = dict(ansi_defaults)
    for c_hex in swatches:
        try:
            r, g, b = hex_to_rgb(c_hex)
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            deg = h * 360.0
            if s > 0.22 and v > 0.30:
                if deg >= 330 or deg < 20:
                    ansi_map["red"] = c_hex
                elif 20 <= deg < 75:
                    ansi_map["yellow"] = c_hex
                elif 75 <= deg < 165:
                    ansi_map["green"] = c_hex
                elif 165 <= deg < 205:
                    ansi_map["cyan"] = c_hex
                elif 205 <= deg < 270:
                    ansi_map["blue"] = c_hex
                elif 270 <= deg < 330:
                    ansi_map["magenta"] = c_hex
        except Exception:
            pass

    c0 = border
    c8 = border_light
    c1 = ansi_map["red"]
    c9_hex = rgb_to_hex(adjust_lightness(hex_to_rgb(c1), 1.15))
    c2 = ansi_map["green"]
    c10 = rgb_to_hex(adjust_lightness(hex_to_rgb(c2), 1.15))
    c3 = ansi_map["yellow"]
    c11 = rgb_to_hex(adjust_lightness(hex_to_rgb(c3), 1.15))
    c4 = accent
    c12 = accent_hover
    c5 = ansi_map["magenta"]
    c13 = rgb_to_hex(adjust_lightness(hex_to_rgb(c5), 1.15))
    c6 = ansi_map["cyan"]
    c14 = rgb_to_hex(adjust_lightness(hex_to_rgb(c6), 1.15))
    c7 = "#bac2de"
    c15 = fg

    # 1. Kitty Terminal (~/.config/kitty/current-theme.conf)
    kitty_dir = os.path.expanduser("~/.config/kitty")
    if os.path.exists(kitty_dir):
        wp_name = os.path.basename(wallpaper_path) if wallpaper_path else "Current Theme"
        kitty_content = f"""# Generated dynamically by simple-bar theme engine
# Wallpaper: {wp_name}

# Special colors
foreground            {fg}
background            {bg}
selection_foreground  #000000
selection_background  {accent}

# Cursor
cursor                {accent}
cursor_text_color     #000000

# URL underline color
url_color             {accent}

# Window borders
active_border_color   {accent}
inactive_border_color {border}
bell_border_color     {c1}

# Tab bar
active_tab_foreground   #000000
active_tab_background   {accent}
inactive_tab_foreground {fg_muted}
inactive_tab_background {surface}
tab_bar_background      {bg}

# Marks
mark1_foreground #000000
mark1_background {accent}
mark2_foreground #000000
mark2_background {secondary}
mark3_foreground #000000
mark3_background {accent_hover}

# Standard 16 terminal colors
color0 {c0}
color8 {c8}
color1 {c1}
color9 {c9_hex}
color2 {c2}
color10 {c10}
color3 {c3}
color11 {c11}
color4 {c4}
color12 {c12}
color5 {c5}
color13 {c13}
color6 {c6}
color14 {c14}
color7 {c7}
color15 {c15}
"""
        theme_path = os.path.join(kitty_dir, "current-theme.conf")
        try:
            with open(theme_path, "w") as f:
                f.write(kitty_content)
            # Signal running kitty instances to reload config
            import subprocess
            subprocess.run(["pkill", "-USR1", "kitty"], capture_output=True)
        except Exception as e:
            sys.stderr.write(f"Failed to export kitty theme: {e}\n")

    # 2. Foot Terminal (~/.config/foot/colors.ini)
    foot_dir = os.path.expanduser("~/.config/foot")
    if os.path.exists(foot_dir):
        def cl(h): return h.lstrip("#")
        foot_content = f"""[colors]
background={cl(bg)}
foreground={cl(fg)}
selection-background={cl(accent)}
selection-foreground=000000
regular0={cl(c0)}
regular1={cl(c1)}
regular2={cl(c2)}
regular3={cl(c3)}
regular4={cl(c4)}
regular5={cl(c5)}
regular6={cl(c6)}
regular7={cl(c7)}
bright0={cl(c8)}
bright1={cl(c9_hex)}
bright2={cl(c10)}
bright3={cl(c11)}
bright4={cl(c12)}
bright5={cl(c13)}
bright6={cl(c14)}
bright7={cl(c15)}
"""
        try:
            with open(os.path.join(foot_dir, "colors.ini"), "w") as f:
                f.write(foot_content)
        except Exception:
            pass

def save_theme_tokens(tokens, wallpaper_path=""):
    """Write tokens to colors.json and simple-bar cache, and export to terminal emulators."""
    try:
        data = {
            "wallpaper": wallpaper_path,
            "updated_at": time.time(),
            "colors": tokens
        }
        with open(COLORS_PATH, "w") as f:
            json.dump(data, f, indent=2)

        # Also write to cache for external desktop scripts
        cache_colors = os.path.join(CACHE_DIR, "colors.json")
        with open(cache_colors, "w") as f:
            json.dump(data, f, indent=2)
            
        # Write CSS variables
        css_file = os.path.join(CACHE_DIR, "colors.css")
        with open(css_file, "w") as f:
            f.write(":root {\n")
            for k, v in tokens.items():
                if isinstance(v, str):
                    f.write(f"  --sb-{k}: {v};\n")
            f.write("}\n")

        # Export to Kitty and Foot terminals
        export_terminal_themes(tokens, wallpaper_path)
    except Exception as e:
        sys.stderr.write(f"Failed to write colors.json: {e}\n")

def get_thumbnail(image_path, size=(280, 160)):
    """Generate or retrieve cached thumbnail for local wallpaper."""
    try:
        import hashlib
        h = hashlib.md5(image_path.encode("utf-8")).hexdigest()
        thumb_name = f"{h}.jpg"
        thumb_path = os.path.join(THUMB_DIR, thumb_name)

        if os.path.exists(thumb_path):
            return thumb_path

        img = Image.open(image_path).convert("RGB")
        img.thumbnail(size, Image.Resampling.LANCZOS)
        img.save(thumb_path, "JPEG", quality=85)
        return thumb_path
    except Exception:
        return image_path

def list_local_wallpapers(folder=None):
    """Scan folder and return list of wallpapers with metadata and thumbnails."""
    if not folder:
        cfg = load_config()
        folder = cfg.get("wallpaper_dir", DEFAULT_WALLPAPER_DIR)

    folder = os.path.expanduser(folder)
    if not os.path.exists(folder):
        return []

    current_wp = get_current_wallpaper()
    patterns = ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
    files = []
    for pat in patterns:
        files.extend(glob.glob(os.path.join(folder, pat)))
        files.extend(glob.glob(os.path.join(folder, pat.upper())))

    files = sorted(list(set(files)), key=lambda p: os.path.getmtime(p), reverse=True)
    results = []
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        thumb = get_thumbnail(f)
        results.append({
            "name": name,
            "filename": os.path.basename(f),
            "path": f,
            "thumb": "file://" + thumb,
            "active": os.path.abspath(f) == os.path.abspath(current_wp) if current_wp else False
        })
    return results

def set_wallpaper_image(image_path, custom_accent=None):
    """
    Apply a wallpaper with randomized transition,
    extract colors, and update configuration.
    """
    ensure_daemon()
    image_path = os.path.abspath(os.path.expanduser(image_path))
    if not os.path.exists(image_path):
        return {"status": "error", "message": "File not found"}

    import subprocess
    trans_args = get_random_transition()
    cmd = ["awww", "img", image_path] + trans_args
    subprocess.run(cmd, capture_output=True)

    cfg = load_config()
    cfg["wallpaper"] = image_path
    save_config(cfg)

    mode = cfg.get("theme_mode", "pitch_black")
    palette = extract_palette(image_path, mode=mode, custom_accent=custom_accent)
    save_theme_tokens(palette, image_path)

    return {
        "status": "ok",
        "wallpaper": image_path,
        "colors": palette,
        "transition": trans_args
    }

def apply_random_wallpaper():
    """Pick a random local wallpaper and apply it."""
    walls = list_local_wallpapers()
    if not walls:
        return {"status": "error", "message": "No wallpapers found"}
    current = get_current_wallpaper()
    choices = [w for w in walls if w["path"] != current]
    choice = random.choice(choices if choices else walls)
    return set_wallpaper_image(choice["path"])

_WALLHAVEN_CACHE = {}

def search_wallhaven(query="", sorting="toplist", page=1):
    """
    Query the Wallhaven API and return formatted results divided into 12 images per page.
    Translates UI page (12 images/page) to Wallhaven API page (24 images/page).
    """
    ui_page = max(1, int(page))
    api_page = ((ui_page - 1) // 2) + 1
    idx_start = 12 if ((ui_page - 1) % 2 == 1) else 0
    idx_end = idx_start + 12

    cache_key = f"{query.strip().lower()}_{sorting}_{api_page}"
    now = time.time()
    data = None

    if cache_key in _WALLHAVEN_CACHE:
        cached_time, cached_data = _WALLHAVEN_CACHE[cache_key]
        if now - cached_time < 300: # 5 min cache
            data = cached_data

    if data is None:
        base_url = "https://wallhaven.cc/api/v1/search"
        params = {
            "sorting": sorting if sorting else "toplist",
            "page": str(api_page),
            "ratios": "16x9,16x10",
            "purity": "100", # SFW only
            "categories": "110" # General + Anime
        }
        if query and query.strip():
            params["q"] = query.strip()

        req_url = base_url + "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(
            req_url,
            headers={"User-Agent": "simple-bar/1.0 (Linux; Wayland)"}
        )

        try:
            with urllib.request.urlopen(req, timeout=8) as response:
                data = json.loads(response.read().decode("utf-8"))
                _WALLHAVEN_CACHE[cache_key] = (now, data)
        except Exception as e:
            sys.stderr.write(f"Wallhaven error: {e}\n")
            return {"status": "error", "message": str(e), "wallpapers": [], "page": ui_page, "last_page": 1}

    raw_items = data.get("data", [])
    sliced_items = raw_items[idx_start:idx_end]

    meta = data.get("meta", {})
    total = meta.get("total", 0)
    if total:
        last_ui_page = max(1, (total + 11) // 12)
    else:
        last_ui_page = max(1, meta.get("last_page", 1) * 2)

    items = []
    for item in sliced_items:
        items.append({
            "id": item.get("id"),
            "resolution": item.get("resolution", "1920x1080"),
            "category": item.get("category", "General"),
            "file_size": item.get("file_size", 0),
            "thumb": item.get("thumbs", {}).get("large") or item.get("thumbs", {}).get("small"),
            "url": item.get("path"),
            "colors": item.get("colors", [])
        })

    return {
        "status": "ok",
        "page": ui_page,
        "last_page": last_ui_page,
        "wallpapers": items
    }

def download_and_apply_wallhaven(wall_id, download_url):
    """
    Download a wallpaper from Wallhaven directly into ~/Pictures/Wallpapers/
    and apply it immediately with randomized transition and color extraction.
    """
    cfg = load_config()
    target_dir = os.path.expanduser(cfg.get("wallpaper_dir", DEFAULT_WALLPAPER_DIR))
    os.makedirs(target_dir, exist_ok=True)

    ext = "jpg"
    if ".png" in download_url:
        ext = "png"
    elif ".webp" in download_url:
        ext = "webp"

    filename = f"wallhaven-{wall_id}.{ext}"
    dest_path = os.path.join(target_dir, filename)

    try:
        req = urllib.request.Request(
            download_url,
            headers={"User-Agent": "simple-bar/1.0 (Linux; Wayland)"}
        )
        with urllib.request.urlopen(req, timeout=20) as response, open(dest_path, "wb") as out_file:
            shutil.copyfileobj(response, out_file)

        # Apply newly downloaded wallpaper
        res = set_wallpaper_image(dest_path)
        res["downloaded_path"] = dest_path
        return res
    except Exception as e:
        sys.stderr.write(f"Download failed: {e}\n")
        return {"status": "error", "message": str(e)}

def init_wallpaper():
    """
    Ensure awww-daemon is running and restore the remembered wallpaper from config.json.
    Also ensures color tokens and terminal themes (Kitty/Foot) are updated.
    """
    ensure_daemon()

    import subprocess
    daemon_ready = False
    for _ in range(15):
        try:
            res = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=1)
            if res.returncode == 0:
                daemon_ready = True
                break
        except Exception:
            pass
        time.sleep(0.2)

    cfg = load_config()
    saved_wp = cfg.get("wallpaper")
    cur_wp = get_current_wallpaper()

    target_wp = None
    if saved_wp and os.path.exists(saved_wp):
        target_wp = saved_wp
    elif cur_wp and os.path.exists(cur_wp):
        target_wp = cur_wp
    else:
        local_walls = list_local_wallpapers()
        if local_walls:
            target_wp = local_walls[0]["path"]

    if target_wp and os.path.exists(target_wp):
        if cur_wp != target_wp:
            subprocess.run(["awww", "img", target_wp, "--transition-type", "fade", "--transition-duration", "1.0"], capture_output=True)
            cfg["wallpaper"] = target_wp
            save_config(cfg)

        mode = cfg.get("theme_mode", "pitch_black")
        palette = extract_palette(target_wp, mode=mode)
        save_theme_tokens(palette, target_wp)
        return {"status": "ok", "wallpaper": target_wp, "daemon_ready": daemon_ready}

    return {"status": "error", "message": "No valid wallpaper found"}

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "list":
            print(json.dumps(list_local_wallpapers()))
        elif cmd == "set" and len(sys.argv) > 2:
            print(json.dumps(set_wallpaper_image(sys.argv[2])))
        elif cmd == "random":
            print(json.dumps(apply_random_wallpaper()))
        elif cmd == "extract" and len(sys.argv) > 2:
            print(json.dumps(extract_palette(sys.argv[2])))
        elif cmd == "current":
            print(json.dumps({"wallpaper": get_current_wallpaper()}))
        elif cmd == "init":
            print(json.dumps(init_wallpaper()))
        elif cmd == "wallhaven":
            q = sys.argv[2] if len(sys.argv) > 2 else ""
            s = sys.argv[3] if len(sys.argv) > 3 else "toplist"
            p = int(sys.argv[4]) if len(sys.argv) > 4 else 1
            print(json.dumps(search_wallhaven(q, s, p)))
        elif cmd == "apply-wallhaven" and len(sys.argv) > 3:
            print(json.dumps(download_and_apply_wallhaven(sys.argv[2], sys.argv[3])))
    else:
        print("Usage: theme.py [list|set|random|extract|current|init|wallhaven|apply-wallhaven]")
