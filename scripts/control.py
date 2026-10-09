#!/usr/bin/env python3
import sys
import subprocess
import json
import os
import glob
import time
import shlex
import re
import shutil
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import theme
except Exception as e:
    theme = None

CONFIG_PATH = os.path.expanduser("~/.config/quickshell/simple-bar/config.json")

def detect_terminal():
    env_term = os.environ.get("TERMINAL")
    if env_term and shutil.which(env_term):
        return env_term
    for term in ['kitty', 'ghostty', 'alacritty', 'foot', 'wezterm', 'xterm', 'gnome-terminal']:
        if shutil.which(term):
            return term
    return 'xterm'

def launch_terminal(cmd_args=None):
    term = detect_terminal()
    if not cmd_args:
        subprocess.Popen([term], start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return term
    if term == 'wezterm':
        full_cmd = [term, 'start', '--'] + list(cmd_args)
    else:
        full_cmd = [term, '-e'] + list(cmd_args)
    subprocess.Popen(full_cmd, start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return term

def get_wifi_device():
    try:
        res = subprocess.run(['nmcli', '-t', '-f', 'DEVICE,TYPE', 'dev'], capture_output=True, text=True, timeout=2)
        for line in res.stdout.strip().splitlines():
            parts = line.split(':')
            if len(parts) >= 2 and parts[1].strip() == 'wifi':
                return parts[0].strip()
    except Exception:
        pass
    return 'wlan0'

def get_weather():
    cache_dir = os.path.expanduser('~/.cache/simple-bar')
    os.makedirs(cache_dir, exist_ok=True)
    cache_file = os.path.join(cache_dir, 'weather.json')

    cfg = load_config()
    lat = cfg.get('weather_lat')
    lon = cfg.get('weather_lon')
    units = cfg.get('weather_units', 'celsius')

    now = time.time()
    if os.path.exists(cache_file):
        try:
            with open(cache_file, 'r', encoding='utf-8') as f:
                cached = json.load(f)
            if now - cached.get('timestamp', 0) < 900:
                return cached.get('data', {})
        except Exception:
            pass

    if lat is None or lon is None:
        try:
            req = urllib.request.Request('http://ip-api.com/json/?fields=lat,lon', headers={'User-Agent': 'simple-bar'})
            with urllib.request.urlopen(req, timeout=3) as resp:
                geo = json.loads(resp.read().decode('utf-8'))
                lat = geo.get('lat')
                lon = geo.get('lon')
                if lat is not None and lon is not None:
                    cfg['weather_lat'] = lat
                    cfg['weather_lon'] = lon
                    save_config(cfg)
        except Exception:
            pass

    if lat is None or lon is None:
        lat, lon = 0.0, 0.0

    temp_unit_param = '&temperature_unit=fahrenheit' if units == 'fahrenheit' else ''
    url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,is_day{temp_unit_param}"

    wmo_desc = {
        0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
        45: "Fog", 48: "Depositing rime fog", 51: "Light drizzle", 53: "Moderate drizzle",
        55: "Dense drizzle", 61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
        71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow", 77: "Snow grains",
        80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
        85: "Slight snow showers", 86: "Heavy snow showers", 95: "Thunderstorm",
        96: "Thunderstorm with hail", 99: "Thunderstorm with heavy hail"
    }

    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'simple-bar'})
        with urllib.request.urlopen(req, timeout=4) as resp:
            raw = json.loads(resp.read().decode('utf-8'))
            curr = raw.get('current', {})
            temp = curr.get('temperature_2m', 0)
            unit_symbol = "°F" if units == 'fahrenheit' else "°C"
            temp_str = f"{round(temp)}{unit_symbol}"
            code = curr.get('weather_code', 0)
            is_day = curr.get('is_day', 1)
            desc = wmo_desc.get(code, "Clear sky")
            data = {
                "temp": temp_str,
                "code": code,
                "is_day": is_day,
                "desc": desc
            }
            with open(cache_file, 'w', encoding='utf-8') as f:
                json.dump({"timestamp": now, "data": data}, f)
            return data
    except Exception:
        if os.path.exists(cache_file):
            try:
                with open(cache_file, 'r', encoding='utf-8') as f:
                    return json.load(f).get('data', {})
            except Exception:
                pass
        return {"temp": "--°C", "code": 0, "is_day": 1, "desc": "Offline"}

def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            pass
    return {"position": "top"}

def save_config(cfg):
    try:
        os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
        with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
            json.dump(cfg, f, indent=2)
    except Exception:
        pass

def clean_app_name(app_id, title=""):
    if not app_id:
        return ""
    mapping = {
        "kitty": "Kitty",
        "alacritty": "Alacritty",
        "foot": "Foot",
        "org.gnome.Nautilus": "Files",
        "nautilus": "Files",
        "firefox": "Firefox",
        "google-chrome": "Chrome",
        "chromium": "Chromium",
        "code": "VS Code",
        "code-oss": "VS Code",
        "antigravity": "Antigravity",
        "antigravity-ide": "Antigravity IDE",
        "blueman-manager": "Bluetooth",
        "pavucontrol": "Volume Control",
        "btop": "Btop",
        "htop": "Htop",
        "mpv": "MPV",
        "vlc": "VLC",
        "spotify": "Spotify",
        "discord": "Discord",
        "slack": "Slack",
        "telegram-desktop": "Telegram",
        "steam": "Steam",
    }
    if app_id in mapping:
        return mapping[app_id]

    entry = find_desktop_entry(app_id)
    if entry and entry.get('name'):
        return entry['name']

    if '.' in app_id:
        return app_id.split('.')[-1].capitalize()
    return app_id.capitalize()

KNOWN_IMAGE_EXTS = {'.png', '.svg', '.xpm', '.ico'}

ICON_SEARCH_DIRS = [
    # 1. User application icons (PWAs, custom AppImages, Grok, WhatsApp, etc.)
    os.path.expanduser('~/.local/share/icons/hicolor/512x512/apps'),
    os.path.expanduser('~/.local/share/icons/hicolor/256x256/apps'),
    os.path.expanduser('~/.local/share/icons/hicolor/128x128/apps'),
    os.path.expanduser('~/.local/share/icons/hicolor/scalable/apps'),
    os.path.expanduser('~/.local/share/icons/hicolor/64x64/apps'),
    os.path.expanduser('~/.local/share/icons/hicolor/48x48/apps'),
    os.path.expanduser('~/.local/share/icons/hicolor/32x32/apps'),
    os.path.expanduser('~/.local/share/icons/hicolor/24x24/apps'),
    os.path.expanduser('~/.local/share/icons/hicolor/16x16/apps'),
    os.path.expanduser('~/.local/share/pixmaps'),

    # Flatpak user & system icons
    os.path.expanduser('~/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps'),
    os.path.expanduser('~/.local/share/flatpak/exports/share/icons/hicolor/512x512/apps'),
    os.path.expanduser('~/.local/share/flatpak/exports/share/icons/hicolor/256x256/apps'),
    os.path.expanduser('~/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps'),
    '/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps',
    '/var/lib/flatpak/exports/share/icons/hicolor/512x512/apps',
    '/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps',
    '/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps',
    '/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps',
    '/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps',
    '/var/lib/flatpak/exports/share/icons/hicolor/32x32/apps',

    # 2. System hicolor (App developers' official bundled full-color icons)
    '/usr/share/icons/hicolor/scalable/apps',
    '/usr/share/icons/hicolor/512x512/apps',
    '/usr/share/icons/hicolor/256x256/apps',
    '/usr/share/icons/hicolor/128x128/apps',
    '/usr/share/icons/hicolor/64x64/apps',
    '/usr/share/icons/hicolor/48x48/apps',
    '/usr/share/icons/hicolor/32x32/apps',
    '/usr/share/icons/hicolor/24x24/apps',
    '/usr/share/icons/hicolor/16x16/apps',

    # 3. Full-color system themes (Papirus, Breeze, Adwaita, Pixmaps)
    '/usr/share/icons/Papirus/128x128/apps',
    '/usr/share/icons/Papirus/64x64/apps',
    '/usr/share/icons/Papirus/48x48/apps',
    '/usr/share/icons/Papirus-Dark/128x128/apps',
    '/usr/share/icons/Papirus-Dark/64x64/apps',
    '/usr/share/icons/Papirus-Dark/48x48/apps',
    '/usr/share/icons/breeze/apps/48',
    '/usr/share/icons/breeze-dark/apps/48',
    '/usr/share/icons/Adwaita/scalable/apps',
    '/usr/share/icons/Adwaita/48x48/apps',
    '/usr/share/pixmaps',

    # 4. Fallback only if no color icon exists anywhere
    os.path.expanduser('~/.local/share/icons/yet-another-monochrome-icon-set/apps/scalable'),
    os.path.expanduser('~/.local/share/icons/yet-another-monochrome-icon-set/devices/scalable'),
]
ICON_DIRS = [d for d in ICON_SEARCH_DIRS if os.path.exists(d)]

def get_desktop_directories():
    dirs = [
        os.path.expanduser('~/.local/share/applications'),
        os.path.expanduser('~/Desktop'),
        '/var/lib/flatpak/exports/share/applications',
        os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
        '/usr/local/share/applications',
        '/usr/share/applications',
        '/var/lib/snapd/desktop/applications',
    ]
    for x in os.environ.get('XDG_DATA_DIRS', '').split(':'):
        if x:
            p = os.path.join(x, 'applications')
            if p not in dirs:
                dirs.append(p)
    return [d for d in dirs if os.path.exists(d)]

_desktop_cache_time = 0
_desktop_cache = {}
_desktop_cache_wmclass = {}
_desktop_cache_pwa = {}

def update_desktop_cache(force=False):
    global _desktop_cache_time, _desktop_cache, _desktop_cache_wmclass, _desktop_cache_pwa
    now = time.time()
    if not force and _desktop_cache and (now - _desktop_cache_time < 30):
        return
    _desktop_cache_time = now
    cache_id = {}
    cache_wm = {}
    cache_pwa = {}
    for d in get_desktop_directories():
        for f in glob.glob(os.path.join(d, '*.desktop')):
            base = os.path.splitext(os.path.basename(f))[0]
            name, icon, wmclass, exec_cmd = '', '', '', ''
            try:
                with open(f, 'r', encoding='utf-8', errors='ignore') as fp:
                    for line in fp:
                        line = line.strip()
                        if line.startswith('Name=') and not name: name = line.split('=', 1)[1]
                        elif line.startswith('Icon=') and not icon: icon = line.split('=', 1)[1]
                        elif line.startswith('StartupWMClass=') and not wmclass: wmclass = line.split('=', 1)[1]
                        elif line.startswith('Exec=') and not exec_cmd: exec_cmd = line.split('=', 1)[1]
            except Exception: pass
            
            if not name: continue
            entry = {'name': name, 'icon': icon, 'path': f, 'wmclass': wmclass, 'exec': exec_cmd}
            if base not in cache_id: cache_id[base] = entry
            if base.lower() not in cache_id: cache_id[base.lower()] = entry
            if wmclass:
                if wmclass not in cache_wm: cache_wm[wmclass] = entry
                if wmclass.lower() not in cache_wm: cache_wm[wmclass.lower()] = entry
            
            pwa_m = re.search(r'--app-id=([a-z0-9]+)', exec_cmd) or re.search(r'([a-z0-9]{32})', base)
            if pwa_m:
                pid = pwa_m.group(1).lower()
                cache_pwa[pid] = entry

    _desktop_cache = cache_id
    _desktop_cache_wmclass = cache_wm
    _desktop_cache_pwa = cache_pwa

def find_desktop_entry(app_id):
    if not app_id: return None
    update_desktop_cache()
    if app_id in _desktop_cache: return _desktop_cache[app_id]
    if app_id.lower() in _desktop_cache: return _desktop_cache[app_id.lower()]
    if app_id in _desktop_cache_wmclass: return _desktop_cache_wmclass[app_id]
    if app_id.lower() in _desktop_cache_wmclass: return _desktop_cache_wmclass[app_id.lower()]
    pwa_m = re.search(r'([a-z0-9]{32})', app_id.lower())
    if pwa_m and pwa_m.group(1) in _desktop_cache_pwa:
        return _desktop_cache_pwa[pwa_m.group(1)]
    if '.' in app_id:
        last = app_id.split('.')[-1]
        if last in _desktop_cache: return _desktop_cache[last]
        if last.lower() in _desktop_cache: return _desktop_cache[last.lower()]
    return None

def resolve_icon(icon_name):
    if not icon_name: return ''
    if os.path.isabs(icon_name) and os.path.exists(icon_name): return icon_name
    if icon_name.startswith('~'):
        p = os.path.expanduser(icon_name)
        if os.path.exists(p): return p

    name_lower = icon_name.lower()
    has_known_ext = any(name_lower.endswith(e) for e in KNOWN_IMAGE_EXTS)
    base_name = os.path.splitext(icon_name)[0] if has_known_ext else icon_name

    exts = ['', '.png', '.svg', '.xpm']
    for d in ICON_DIRS:
        for e in exts:
            p = os.path.join(d, base_name + e)
            if os.path.exists(p): return p
    return ''

def get_installed_apps():
    apps = []
    seen = set()
    dirs = get_desktop_directories()
    for d in dirs:
        for f in glob.glob(os.path.join(d, '*.desktop')):
            try:
                name, exec_cmd, icon, comment, cat, nodisplay = '', '', '', '', 'Utility', False
                with open(f, 'r', encoding='utf-8', errors='ignore') as fp:
                    in_entry = False
                    for line in fp:
                        line = line.strip()
                        if line == '[Desktop Entry]':
                            in_entry = True
                            continue
                        elif line.startswith('[') and in_entry:
                            break
                        if in_entry and '=' in line:
                            k, v = line.split('=', 1)
                            if k == 'Name' and not name: name = v
                            elif k == 'Exec' and not exec_cmd: exec_cmd = v
                            elif k == 'Icon' and not icon: icon = v
                            elif k == 'Comment' and not comment: comment = v
                            elif k == 'Categories':
                                if 'Game' in v or 'Games' in v: cat = 'Games'
                                elif 'Development' in v: cat = 'Development'
                                elif 'Network' in v or 'Web' in v: cat = 'Internet'
                                elif 'Audio' in v or 'Video' in v or 'Media' in v or 'Graphics' in v: cat = 'Media'
                                elif 'Office' in v: cat = 'Office'
                                elif 'System' in v or 'Settings' in v: cat = 'System'
                            elif k == 'NoDisplay' and v.lower() == 'true': nodisplay = True
                # Desktop folder items are explicitly pinned by user
                if '/Desktop/' in f or f.startswith(os.path.expanduser('~/Desktop')):
                    nodisplay = False
                if name and exec_cmd and not nodisplay:
                    if name.lower() in seen: continue
                    seen.add(name.lower())
                    clean_exec = ' '.join([p for p in exec_cmd.split() if not p.startswith('%')])
                    icon_path = resolve_icon(icon)
                    is_web_app = ('--app-id=' in exec_cmd or '--app=' in exec_cmd or os.path.basename(f).startswith('chrome-'))
                    apps.append({
                        'name': name,
                        'exec': clean_exec,
                        'icon': icon,
                        'icon_path': icon_path,
                        'comment': comment or cat,
                        'category': cat,
                        'is_web_app': is_web_app
                    })
            except Exception:
                pass
    apps.sort(key=lambda x: x['name'].lower())
    return apps

def stream_wm():
    def resolve_focused_icon(app_id):
        if not app_id: return ''
        entry = find_desktop_entry(app_id)
        if entry and entry.get('icon'):
            found = resolve_icon(entry['icon'])
            if found: return found
        candidates = [app_id, app_id.lower(), app_id.split('.')[-1].lower() if '.' in app_id else '']
        for name in candidates:
            if not name: continue
            found = resolve_icon(name)
            if found: return found
        return ''

    state = {'focused_app': '', 'focused_app_name': '', 'focused_title': '', 'focused_icon_path': '', 'active_ws': 1, 'workspaces': [], 'windows': {}}
    
    def emit(ws_event=False):
        print(json.dumps({
            'type': 'wm',
            'focused_app': state['focused_app'],
            'focused_app_name': state['focused_app_name'],
            'focused_title': state['focused_title'],
            'focused_icon_path': state['focused_icon_path'],
            'active_ws': state['active_ws'],
            'workspaces': state['workspaces'],
            'ws_event': ws_event
        }), flush=True)

    # Initial query for Niri
    try:
        r = subprocess.run(['niri', 'msg', '-j', 'focused-window'], capture_output=True, text=True, timeout=1)
        if r.returncode == 0 and r.stdout.strip():
            w = json.loads(r.stdout)
            if w:
                state['focused_app'] = w.get('app_id', '')
                state['focused_app_name'] = clean_app_name(state['focused_app'], w.get('title', ''))
                state['focused_title'] = w.get('title', '')
                state['focused_icon_path'] = resolve_focused_icon(state['focused_app'])
    except Exception:
        pass

    try:
        r = subprocess.run(['niri', 'msg', '-j', 'workspaces'], capture_output=True, text=True, timeout=1)
        if r.returncode == 0 and r.stdout.strip():
            state['workspaces'] = []
            for w in sorted(json.loads(r.stdout), key=lambda x: x.get('idx', 0)):
                act = w.get('is_active', False) or w.get('is_focused', False)
                if act: state['active_ws'] = w.get('idx', 1)
                state['workspaces'].append({'idx': w.get('idx', 1), 'id': w.get('id'), 'name': w.get('name') or str(w.get('idx', 1)), 'active': act})
    except Exception:
        pass

    emit(ws_event=False)

    # Hardware event monitoring for instant Volume and Brightness feedback
    import threading

    def monitor_audio():
        last_v, last_m = None, None
        try:
            p = subprocess.Popen(['pactl', 'subscribe'], stdout=subprocess.PIPE, text=True)
            for line in p.stdout:
                if 'sink' in line or 'change' in line:
                    try:
                        wp_res = subprocess.run(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'], capture_output=True, text=True, timeout=1)
                        out = wp_res.stdout.strip()
                        muted = 'MUTED' in out
                        parts = out.split()
                        vol = round(float(parts[1]) * 100) if len(parts) >= 2 else 50
                        if last_v is not None and (vol != last_v or muted != last_m):
                            print(json.dumps({'type': 'volume', 'volume': vol, 'muted': muted}), flush=True)
                        last_v, last_m = vol, muted
                    except Exception:
                        pass
        except Exception:
            pass

    def monitor_brightness():
        last_b = None
        bl_dirs = glob.glob('/sys/class/backlight/*')
        bl_base = bl_dirs[0] if bl_dirs else ''
        bl_file = os.path.join(bl_base, 'actual_brightness') if bl_base else ''
        max_file = os.path.join(bl_base, 'max_brightness') if bl_base else ''
        has_bl = bool(bl_base and os.path.exists(bl_file) and os.path.exists(max_file))
        max_val = 1
        if has_bl:
            try:
                with open(max_file) as f:
                    max_val = int(f.read().strip()) or 1
            except Exception:
                has_bl = False

        while True:
            try:
                if has_bl:
                    with open(bl_file) as f:
                        cur = int(f.read().strip())
                    pct = round(cur * 100 / max_val)
                else:
                    br_res = subprocess.run(['brightnessctl', '-m'], capture_output=True, text=True, timeout=1)
                    parts = br_res.stdout.strip().split(',')
                    pct = int(parts[3].replace('%', '')) if len(parts) >= 4 else 50

                if last_b is not None and pct != last_b:
                    print(json.dumps({'type': 'brightness', 'brightness': pct}), flush=True)
                last_b = pct
            except Exception:
                pass
            time.sleep(0.15)

    def monitor_wallpaper():
        if not theme: return
        try:
            theme.init_wallpaper()
        except Exception:
            pass
        last_wp = None
        while True:
            try:
                cur_wp = theme.get_current_wallpaper()
                if cur_wp and cur_wp != last_wp:
                    mode = theme.load_config().get("theme_mode", "pitch_black")
                    palette = theme.extract_palette(cur_wp, mode=mode)
                    theme.save_theme_tokens(palette, cur_wp)
                    print(json.dumps({
                        'type': 'theme',
                        'wallpaper': cur_wp,
                        'colors': palette,
                        'swatches': palette.get('palette', [])
                    }), flush=True)
                    last_wp = cur_wp
            except Exception:
                pass
            time.sleep(2.0)

    threading.Thread(target=monitor_audio, daemon=True).start()
    threading.Thread(target=monitor_brightness, daemon=True).start()
    threading.Thread(target=monitor_wallpaper, daemon=True).start()

    # Niri Event Stream
    try:
        proc = subprocess.Popen(['niri', 'msg', '-j', 'event-stream'], stdout=subprocess.PIPE, text=True)
        while True:
            line = proc.stdout.readline()
            if not line: break
            try:
                ev = json.loads(line)
                key = list(ev.keys())[0]
                val = ev[key]
                ws_switched = False
                changed = False

                if key == 'WorkspacesChanged':
                    state['workspaces'] = []
                    new_active = state['active_ws']
                    for w in sorted(val.get('workspaces', []), key=lambda x: x.get('idx', 0)):
                        act = w.get('is_active', False) or w.get('is_focused', False)
                        if act: new_active = w.get('idx', 1)
                        state['workspaces'].append({'idx': w.get('idx', 1), 'id': w.get('id'), 'name': w.get('name') or str(w.get('idx', 1)), 'active': act})
                    if new_active != state['active_ws']:
                        state['active_ws'] = new_active
                        ws_switched = True
                    changed = True

                elif key == 'WorkspaceActivated':
                    ws_id = val.get('id')
                    for w in state['workspaces']:
                        is_this = (w.get('id') == ws_id)
                        w['active'] = is_this
                        if is_this and w.get('idx') != state['active_ws']:
                            state['active_ws'] = w.get('idx')
                            ws_switched = True
                    changed = True

                elif key == 'WindowsChanged':
                    state['windows'] = {w['id']: w for w in val.get('windows', [])}
                    focused = next((w for w in val.get('windows', []) if w.get('is_focused')), None)
                    new_app = focused.get('app_id', '') if focused else ''
                    new_title = focused.get('title', '') if focused else ''
                    if new_app != state['focused_app'] or new_title != state['focused_title']:
                        state['focused_app'] = new_app
                        state['focused_app_name'] = clean_app_name(new_app, new_title)
                        state['focused_title'] = new_title
                        state['focused_icon_path'] = resolve_focused_icon(new_app)
                        changed = True

                elif key == 'WindowFocusChanged':
                    win_id = val.get('id')
                    if win_id and win_id in state['windows']:
                        w = state['windows'][win_id]
                        new_app = w.get('app_id', '')
                        new_title = w.get('title', '')
                    else:
                        new_app = ''
                        new_title = ''
                    if new_app != state['focused_app'] or new_title != state['focused_title']:
                        state['focused_app'] = new_app
                        state['focused_app_name'] = clean_app_name(new_app, new_title)
                        state['focused_title'] = new_title
                        state['focused_icon_path'] = resolve_focused_icon(new_app)
                        changed = True

                elif key == 'WindowOpenedOrChanged':
                    w = val.get('window', {})
                    if w.get('id'):
                        state['windows'][w['id']] = w
                        if w.get('is_focused'):
                            new_app = w.get('app_id', '')
                            new_title = w.get('title', '')
                            state['focused_app'] = new_app
                            state['focused_app_name'] = clean_app_name(new_app, new_title)
                            state['focused_title'] = new_title
                            state['focused_icon_path'] = resolve_focused_icon(new_app)
                            changed = True

                elif key == 'WindowClosed':
                    win_id = val.get('id')
                    if win_id in state['windows']:
                        del state['windows'][win_id]

                if changed or ws_switched:
                    emit(ws_event=ws_switched)

            except Exception:
                pass
    except Exception:
        # Fallback polling loop if niri event stream fails
        while True:
            time.sleep(1)

def get_status():
    # WiFi
    wifi_radio = False
    try:
        r = subprocess.run(['nmcli', 'radio', 'wifi'], capture_output=True, text=True, timeout=2)
        wifi_radio = r.stdout.strip() == 'enabled'
    except Exception:
        pass

    wifi_connected = False
    wifi_ssid = "Disconnected"
    wifi_signal = 0
    wifi_networks = []
    seen_ssids = set()

    if wifi_radio:
        try:
            res = subprocess.run(['nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list', '--rescan', 'no'], capture_output=True, text=True, timeout=3)
            for line in res.stdout.strip().split('\n'):
                if not line: continue
                parts = line.split(':')
                if len(parts) >= 4:
                    in_use = parts[0] == '*'
                    ssid = parts[1].strip()
                    if not ssid or ssid in seen_ssids: continue
                    seen_ssids.add(ssid)
                    sig = int(parts[2]) if parts[2].isdigit() else 0
                    sec = parts[3].strip()
                    if in_use:
                        wifi_connected = True
                        wifi_ssid = ssid
                        wifi_signal = sig
                    wifi_networks.append({'ssid': ssid, 'signal': sig, 'security': sec, 'inUse': in_use})
        except Exception:
            pass

    # Bluetooth
    bt_powered = False
    bt_devices = []
    bt_connected_name = "None"
    bt_connected = False

    try:
        bt_show = subprocess.run(['bluetoothctl', 'show'], capture_output=True, text=True, timeout=2).stdout
        bt_powered = 'Powered: yes' in bt_show

        if bt_powered:
            dev_res = subprocess.run(['bluetoothctl', 'devices'], capture_output=True, text=True, timeout=2)
            conn_res = subprocess.run(['bluetoothctl', 'devices', 'Connected'], capture_output=True, text=True, timeout=2)
            connected_macs = set()
            for line in conn_res.stdout.strip().split('\n'):
                if line.startswith('Device '):
                    mac = line.split(' ')[1]
                    connected_macs.add(mac)
                    parts = line.split(' ', 2)
                    if len(parts) > 2:
                        bt_connected_name = parts[2]
                        bt_connected = True

            for line in dev_res.stdout.strip().split('\n'):
                if line.startswith('Device '):
                    parts = line.split(' ', 2)
                    mac = parts[1]
                    name = parts[2] if len(parts) > 2 else mac
                    is_conn = mac in connected_macs
                    bt_devices.append({'mac': mac, 'name': name, 'connected': is_conn})
    except Exception:
        pass

    # Brightness
    br_pct = 50
    try:
        br_res = subprocess.run(['brightnessctl', '-m'], capture_output=True, text=True, timeout=2)
        parts = br_res.stdout.strip().split(',')
        if len(parts) >= 4:
            br_pct = int(parts[3].replace('%', ''))
    except Exception:
        pass

    # CPU & RAM & Swap
    cpu_pct = 0
    mem_used = "0 GB"
    mem_total = "0 GB"
    mem_pct = 0.0
    swap_used = "0 GB"
    swap_pct = 0.0
    try:
        with open('/proc/meminfo') as f:
            lines = f.readlines()
        t = a = swap_t = swap_f = 0
        for l in lines:
            if 'MemTotal' in l: t = int(l.split()[1])
            elif 'MemAvailable' in l: a = int(l.split()[1])
            elif 'SwapTotal' in l: swap_t = int(l.split()[1])
            elif 'SwapFree' in l: swap_f = int(l.split()[1])
        if t > 0:
            used = (t - a) / 1024 / 1024
            total = t / 1024 / 1024
            mem_pct = round((t - a) / t, 2)
            mem_used = f"{used:.1f} GB"
            mem_total = f"{total:.1f} GB"
        if swap_t > 0:
            s_used = (swap_t - swap_f) / 1024 / 1024
            swap_pct = round((swap_t - swap_f) / swap_t, 2)
            swap_used = f"{s_used:.1f} GB"

        top_res = subprocess.run("top -bn1 | grep 'Cpu(s)' | awk '{print $2+$4}'", shell=True, capture_output=True, text=True, timeout=2)
        cpu_pct = round(float(top_res.stdout.strip() or 0))
    except Exception:
        pass

    # CPU Temperature
    cpu_temp = 0
    try:
        import glob
        temp_files = glob.glob('/sys/class/thermal/thermal_zone*/temp')
        # Prefer zone0 (usually CPU), fallback to max
        for tf in sorted(temp_files):
            with open(tf) as f:
                t_raw = int(f.read().strip())
            if t_raw > 1000:  # millidegrees
                cpu_temp = max(cpu_temp, t_raw // 1000)
            else:
                cpu_temp = max(cpu_temp, t_raw)
        # Try hwmon as fallback
        if cpu_temp == 0:
            for hf in glob.glob('/sys/class/hwmon/hwmon*/temp1_input'):
                with open(hf) as f:
                    t_raw = int(f.read().strip())
                cpu_temp = max(cpu_temp, t_raw // 1000)
    except Exception:
        pass

    # Audio
    vol_pct = 50
    vol_muted = False
    try:
        wp_res = subprocess.run(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'], capture_output=True, text=True, timeout=1)
        line = wp_res.stdout.strip()
        vol_muted = 'MUTED' in line
        parts = line.split()
        if len(parts) >= 2:
            vol_pct = round(float(parts[1]) * 100)
    except Exception:
        pass

    theme_data = None
    if theme:
        try:
            cur_wp = theme.get_current_wallpaper()
            if os.path.exists(theme.COLORS_PATH):
                with open(theme.COLORS_PATH, "r") as f:
                    theme_data = json.load(f)
            else:
                pal = theme.extract_palette(cur_wp)
                theme.save_theme_tokens(pal, cur_wp)
                theme_data = {"wallpaper": cur_wp, "colors": pal}
        except Exception:
            pass

    return {
        "config": load_config(),
        "audio": {
            "volume": vol_pct,
            "muted": vol_muted
        },
        "wifi": {
            "powered": wifi_radio,
            "connected": wifi_connected,
            "ssid": wifi_ssid,
            "signal": wifi_signal,
            "networks": wifi_networks[:12]
        },
        "bt": {
            "powered": bt_powered,
            "connected": bt_connected,
            "device": bt_connected_name,
            "devices": bt_devices
        },
        "brightness": br_pct,
        "cpu": cpu_pct,
        "cpu_temp": cpu_temp,
        "mem": {
            "used": mem_used,
            "total": mem_total,
            "percent": mem_pct
        },
        "swap": {
            "used": swap_used,
            "percent": swap_pct
        },
        "theme": theme_data
    }

def get_clipboard_items(limit=100):
    try:
        res = subprocess.run(['cliphist', 'list'], capture_output=True, text=True, errors='replace', timeout=2)
        lines = res.stdout.splitlines()[:limit]
    except Exception:
        return []

    thumb_dir = '/tmp/cliphist-previews'
    os.makedirs(thumb_dir, exist_ok=True)
    items = []

    for line in lines:
        parts = line.split('\t', 1)
        if len(parts) < 2:
            continue
        cid = parts[0].strip()
        raw = parts[1].strip()
        is_img = bool(re.search(r'\[\[.*binary data.*\]\]', raw))
        if is_img:
            dims_match = re.search(r'(\d+x\d+)', raw)
            dims = dims_match.group(1) if dims_match else ''
            size_match = re.search(r'(\d+\s*[KkMmGg]?[iI]?[bB])', raw)
            size_str = size_match.group(1) if size_match else ''
            thumb_path = f'{thumb_dir}/{cid}.png'
            if not os.path.exists(thumb_path):
                try:
                    with open(thumb_path, 'wb') as f:
                        subprocess.run(['cliphist', 'decode', cid], stdout=f, timeout=1.5)
                except Exception:
                    pass
            items.append({
                'id': cid,
                'type': 'image',
                'dims': dims,
                'size': size_str,
                'thumb': thumb_path,
                'preview': f'Image ({dims})' if dims else 'Copied Image'
            })
        else:
            items.append({
                'id': cid,
                'type': 'text',
                'preview': raw[:220].replace('\n', ' ↵ ')
            })
    return items

def copy_clipboard_item(cid, auto_paste=True):
    try:
        p1 = subprocess.Popen(['cliphist', 'decode', str(cid)], stdout=subprocess.PIPE)
        p2 = subprocess.Popen(['wl-copy'], stdin=p1.stdout)
        p1.stdout.close()
        p2.wait()
        if auto_paste:
            time.sleep(0.08)
            subprocess.Popen(['wtype', '-M', 'ctrl', '-k', 'v', '-m', 'ctrl'])
        return True
    except Exception:
        return False

def delete_clipboard_item(cid):
    try:
        subprocess.run(f"cliphist decode '{cid}' | cliphist delete", shell=True, timeout=2)
        thumb_path = f'/tmp/cliphist-previews/{cid}.png'
        if os.path.exists(thumb_path):
            try:
                os.remove(thumb_path)
            except Exception:
                pass
        return True
    except Exception:
        return False

def clear_clipboard():
    try:
        subprocess.run(['cliphist', 'wipe'], timeout=2)
        import shutil
        shutil.rmtree('/tmp/cliphist-previews', ignore_errors=True)
        return True
    except Exception:
        return False

TLP_PROFILE_COMMANDS = {
    "performance": "performance",
    "balanced": "balanced",
    "power-saver": "power-saver",
}

def sync_tlp_profile(profile):
    """Apply a requested TLP profile through tlp-pd's unprivileged client."""
    if profile not in TLP_PROFILE_COMMANDS:
        return {"status": "error", "message": "Unknown power profile"}
    if not shutil.which("tlpctl"):
        return {"status": "error", "message": "tlpctl is missing; install TLP and tlp-pd"}

    try:
        current_result = subprocess.run(
            ["tlpctl", "get"], capture_output=True, text=True, timeout=5
        )
        current = current_result.stdout.strip().lower()
        if current_result.returncode != 0 or current not in TLP_PROFILE_COMMANDS:
            stderr_lines = current_result.stderr.strip().splitlines()
            detail = stderr_lines[-1] if stderr_lines else "TLP Profiles Daemon is unavailable"
            return {"status": "error", "message": detail, "profile": current or "unknown"}

        if current == profile:
            return {"status": "ok", "profile": current, "changed": False}

        result = subprocess.run(
            ["tlpctl", TLP_PROFILE_COMMANDS[profile]],
            capture_output=True,
            text=True,
            timeout=8,
        )
        if result.returncode != 0:
            error_lines = (result.stderr.strip() or result.stdout.strip()).splitlines()
            detail = error_lines[-1] if error_lines else "TLP rejected the profile change"
            return {"status": "error", "message": detail, "profile": current}

        # tlpctl can acknowledge the D-Bus request before tlp-pd publishes its
        # new active profile. Poll briefly instead of reporting a false failure
        # from an immediate read of the previous profile.
        verify = None
        applied = current
        for attempt in range(10):
            verify = subprocess.run(
                ["tlpctl", "get"], capture_output=True, text=True, timeout=5
            )
            applied = verify.stdout.strip().lower()
            if verify.returncode == 0 and applied == profile:
                break
            if attempt < 9:
                time.sleep(0.25)

        if verify.returncode != 0 or applied != profile:
            error_lines = verify.stderr.strip().splitlines()
            detail = error_lines[-1] if error_lines else f"TLP still reports {applied or 'an unknown profile'}"
            return {"status": "error", "message": detail, "profile": applied or current}

        return {"status": "ok", "profile": applied, "changed": True}
    except (OSError, subprocess.TimeoutExpired) as e:
        return {"status": "error", "message": str(e), "profile": "unknown"}

def get_system_info():
    uptime_str = "Unknown"
    try:
        with open("/proc/uptime", "r") as f:
            total_seconds = float(f.readline().split()[0])
        hours = int(total_seconds // 3600)
        minutes = int((total_seconds % 3600) // 60)
        if hours > 24:
            days = hours // 24
            rem_h = hours % 24
            uptime_str = f"{days}d {rem_h}h {minutes}m"
        elif hours > 0:
            uptime_str = f"{hours}h {minutes}m"
        else:
            uptime_str = f"{minutes}m"
    except Exception:
        pass

    user = os.environ.get("USER", "user")
    import socket
    try:
        hostname = socket.gethostname()
    except Exception:
        hostname = "linux"

    return {
        "user": user,
        "hostname": hostname,
        "uptime": uptime_str,
        "host_str": f"{user}@{hostname}"
    }

def clean_action_title(action_str):
    act = action_str.strip().rstrip(';').strip()
    spawn_m = re.match(r'spawn(?:-sh)?\s+([^\;]+)', act)
    if spawn_m:
        raw_cmd = spawn_m.group(1).strip()
        parts = re.findall(r'\"([^\"]+)\"', raw_cmd)
        if parts:
            prog = os.path.basename(parts[0])
            if prog in ['kitty', 'foot', 'alacritty', 'ghostty']:
                return 'Open Terminal'
            elif prog in ['nautilus', 'thunar', 'dolphin']:
                return 'Open File Manager'
            elif prog == 'pavucontrol':
                return 'Volume Mixer'
            elif prog == 'qs':
                if 'launcher' in raw_cmd: return 'App Launcher'
                if 'clipboard' in raw_cmd: return 'Clipboard History'
                if 'cheatsheet' in raw_cmd: return 'Cheatsheet'
                if 'power' in raw_cmd: return 'Power Menu'
                if 'bar' in raw_cmd and 'nextWorkspace' in raw_cmd: return 'Next Bar Workspace'
                if 'bar' in raw_cmd and 'prevWorkspace' in raw_cmd: return 'Previous Bar Workspace'
            return f'Launch {prog.capitalize()}'
        return f'Run: {raw_cmd[:28]}'
    
    words = act.split()
    if words:
        name = words[0].replace('-', ' ').title()
        args = ' '.join(words[1:])
        return f'{name} {args}'.strip()
    return act

def categorize_bind(cat_raw, action, chord):
    c_lower = (cat_raw + ' ' + action + ' ' + chord).lower()
    if any(k in c_lower for k in ['screenshot', 'print', 'slurp']):
        return 'Screenshots'
    if any(k in c_lower for k in ['audio', 'volume', 'xf86', 'brightness', 'media', 'play', 'pause', 'next', 'prev', 'monitors']):
        return 'Media & Audio'
    if any(k in c_lower for k in ['workspace', 'monitor']):
        return 'Workspaces'
    if any(k in c_lower for k in ['focus', 'move-column', 'consume', 'expel', 'window', 'close-window', 'center-column']):
        return 'Windows & Navigation'
    if any(k in c_lower for k in ['layout', 'column-width', 'preset', 'height', 'width', 'gap', 'fullscreen']):
        return 'Layout & Sizing'
    if any(k in c_lower for k in ['launcher', 'clipboard', 'cheatsheet', 'bar', 'panel', 'fuzzel']):
        return 'Shell & Panels'
    if any(k in c_lower for k in ['terminal', 'files', 'kitty', 'nautilus', 'app', 'localsend']):
        return 'Apps & Launchers'
    if any(k in c_lower for k in ['quit', 'power', 'lock', 'reboot', 'suspend', 'emergency', 'inhibit']):
        return 'Session & Power'
    return 'Windows & Navigation'

def get_niri_binds():
    config_dir = os.path.expanduser('~/.config/niri')
    files = [os.path.join(config_dir, 'config.kdl')]
    config_d = os.path.join(config_dir, 'config.d')
    if os.path.isdir(config_d):
        files.extend(sorted(glob.glob(os.path.join(config_d, '*.kdl'))))
    
    binds = []
    seen = set()
    
    for fpath in files:
        if not os.path.exists(fpath): continue
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
            
        current_header = os.path.basename(fpath)
        for idx, line in enumerate(lines):
            line_str = line.strip()
            if line_str.startswith('//') and any(s in line_str for s in ['══', '──']):
                if idx + 1 < len(lines):
                    nl = lines[idx+1].strip().lstrip('/ ').strip()
                    if nl and not nl.startswith('═') and not nl.startswith('─'):
                        current_header = nl
                        
            m = re.match(r'^\s*([A-Za-z0-9_+-]+(?:[+][A-Za-z0-9_+-]+)*)\s*(.*?)\s*\{(.*)', line)
            if m:
                chord = m.group(1).strip()
                meta = m.group(2).strip()
                rest = m.group(3).strip()
                
                if chord in ['layout', 'window-rule', 'binds', 'prefer-no-csd', 'hotkey-overlay', 'debug', 'input', 'output', 'cursor', 'environment']:
                    continue
                if not any(k in chord for k in ['Mod', 'Ctrl', 'Alt', 'Shift', 'Super', 'XF86', 'Print', 'Home', 'End', 'Page', 'Left', 'Right', 'Up', 'Down', 'TAB', 'Return', 'Space', 'Delete', 'Backspace', 'Escape']):
                    continue
                
                title = ''
                title_m = re.search(r'hotkey-overlay-title=[\"\']([^\"\']+)[\"\']', meta)
                if title_m:
                    title = title_m.group(1).strip()
                
                action = ''
                if rest and '}' in rest:
                    action = rest.split('}')[0].strip()
                else:
                    for next_idx in range(idx + 1, min(idx + 6, len(lines))):
                        sub_l = lines[next_idx].strip()
                        if '}' in sub_l:
                            inner = sub_l.split('}')[0].strip()
                            if inner: action = inner
                            break
                        elif sub_l and not sub_l.startswith('//'):
                            action = sub_l.rstrip(';').strip()
                            break
                
                if not title:
                    title = clean_action_title(action) if action else chord
                    
                cat = categorize_bind(current_header, action, chord)
                key_tuple = (chord, title)
                if key_tuple not in seen:
                    seen.add(key_tuple)
                    binds.append({
                        'chord': chord,
                        'title': title,
                        'action': action,
                        'category': cat,
                        'keys': chord.split('+')
                    })
    return binds

def main():
    if len(sys.argv) <= 1 or sys.argv[1] == "status":
        print(json.dumps(get_status()))
        return

    cmd = sys.argv[1]

    if cmd == "sync-power-profile" and len(sys.argv) > 2:
        print(json.dumps(sync_tlp_profile(sys.argv[2])))

    elif cmd == "wm-stream":
        stream_wm()

    elif cmd == "focus-workspace" and len(sys.argv) > 2:
        ws = sys.argv[2]
        subprocess.run(['niri', 'msg', 'action', 'focus-workspace', str(ws)], capture_output=True)
        print(json.dumps({"status": "ok", "workspace": ws}))

    elif cmd == "get-apps":
        print(json.dumps(get_installed_apps()))

    elif cmd == "launch-app" and len(sys.argv) > 2:
        exec_cmd = sys.argv[2]
        try:
            # Launched apps must not inherit Quickshell's stdout pipe: it closes as soon
            # as this script exits, and Electron apps crash with EPIPE when they log.
            subprocess.Popen(exec_cmd, shell=True, start_new_session=True,
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            print(json.dumps({"status": "ok", "exec": exec_cmd}))
        except Exception as e:
            print(json.dumps({"status": "error", "message": str(e)}))

    elif cmd == "get-config":
        print(json.dumps(load_config()))

    elif cmd == "set-config" and len(sys.argv) > 3:
        key = sys.argv[2]
        val = sys.argv[3]
        cfg = load_config()
        cfg[key] = val
        save_config(cfg)
        print(json.dumps(cfg))

    elif cmd == "toggle-wifi":
        curr = subprocess.run(['nmcli', 'radio', 'wifi'], capture_output=True, text=True).stdout.strip() == 'enabled'
        subprocess.run(['nmcli', 'radio', 'wifi', 'off' if curr else 'on'])
        print(json.dumps(get_status()))

    elif cmd == "rescan-wifi":
        subprocess.run(['nmcli', 'dev', 'wifi', 'list', '--rescan', 'yes'], capture_output=True)
        print(json.dumps(get_status()))

    elif cmd == "connect-wifi" and len(sys.argv) > 2:
        ssid = sys.argv[2]
        subprocess.Popen(['nmcli', 'dev', 'wifi', 'connect', ssid])
        print(json.dumps({"status": "connecting", "ssid": ssid}))

    elif cmd == "launch-terminal" and len(sys.argv) > 2:
        cmd_args = sys.argv[2:]
        term = launch_terminal(cmd_args)
        print(json.dumps({"status": "ok", "terminal": term, "cmd": cmd_args}))

    elif cmd == "weather":
        print(json.dumps(get_weather()))

    elif cmd == "disconnect-wifi":
        wdev = get_wifi_device()
        subprocess.run(['nmcli', 'dev', 'disconnect', wdev], capture_output=True)
        print(json.dumps(get_status()))

    elif cmd == "toggle-bt":
        show = subprocess.run(['bluetoothctl', 'show'], capture_output=True, text=True).stdout
        powered = 'Powered: yes' in show
        subprocess.run(['bluetoothctl', 'power', 'off' if powered else 'on'])
        print(json.dumps(get_status()))

    elif cmd == "connect-bt" and len(sys.argv) > 2:
        mac = sys.argv[2]
        subprocess.Popen(['bluetoothctl', 'connect', mac])
        print(json.dumps({"status": "connecting", "mac": mac}))

    elif cmd == "disconnect-bt" and len(sys.argv) > 2:
        mac = sys.argv[2]
        subprocess.run(['bluetoothctl', 'disconnect', mac], capture_output=True)
        print(json.dumps(get_status()))

    elif cmd == "open-bt-manager":
        if shutil.which('blueman-manager'):
            subprocess.Popen(['blueman-manager'], start_new_session=True,
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            launch_terminal(['bluetoothctl'])
        print(json.dumps({"status": "ok"}))

    elif cmd == "set-brightness" and len(sys.argv) > 2:
        val = max(1, min(100, int(sys.argv[2])))
        subprocess.run(['brightnessctl', 'set', f"{val}%"], capture_output=True)
        print(json.dumps({"brightness": val}))

    elif cmd == "set-volume" and len(sys.argv) > 2:
        val = max(0, min(100, int(sys.argv[2])))
        subprocess.run(['wpctl', 'set-volume', '@DEFAULT_AUDIO_SINK@', f"{val}%"], capture_output=True)
        if val > 0:
            subprocess.run(['wpctl', 'set-mute', '@DEFAULT_AUDIO_SINK@', '0'], capture_output=True)
        print(json.dumps({"volume": val, "muted": False}))

    elif cmd == "toggle-mute":
        subprocess.run(['wpctl', 'set-mute', '@DEFAULT_AUDIO_SINK@', 'toggle'], capture_output=True)
        print(json.dumps(get_status()))

    elif cmd == "get-clipboard":
        print(json.dumps(get_clipboard_items()))

    elif cmd == "copy-clipboard" and len(sys.argv) > 2:
        cid = sys.argv[2]
        paste = sys.argv[3].lower() == 'true' if len(sys.argv) > 3 else False
        ok = copy_clipboard_item(cid, auto_paste=paste)
        print(json.dumps({"status": "ok" if ok else "error", "id": cid}))

    elif cmd == "delete-clipboard" and len(sys.argv) > 2:
        cid = sys.argv[2]
        ok = delete_clipboard_item(cid)
        print(json.dumps({"status": "ok" if ok else "error", "id": cid}))

    elif cmd == "clear-clipboard":
        ok = clear_clipboard()
        print(json.dumps({"status": "ok" if ok else "error"}))

    elif cmd == "power-action" and len(sys.argv) > 2:
        action = sys.argv[2]
        if action == "lock":
            locker = os.environ.get("LOCKER")
            if locker and shutil.which(locker):
                subprocess.Popen([locker], start_new_session=True)
            elif shutil.which('swaylock'):
                subprocess.Popen(['swaylock', '-f'], start_new_session=True)
            elif shutil.which('hyprlock'):
                subprocess.Popen(['hyprlock'], start_new_session=True)
            elif shutil.which('waylock'):
                subprocess.Popen(['waylock'], start_new_session=True)
        elif action == "sleep":
            subprocess.Popen(['systemctl', 'suspend'])
        elif action == "logout":
            if shutil.which('niri'):
                subprocess.Popen(['niri', 'msg', 'action', 'quit', '--skip-confirmation'])
            else:
                subprocess.Popen(['loginctl', 'terminate-user', os.environ.get('USER', '')])
        elif action == "reboot":
            subprocess.Popen(['systemctl', 'reboot'])
        elif action == "poweroff":
            subprocess.Popen(['systemctl', 'poweroff'])
        elif action == "firmware":
            subprocess.Popen(['systemctl', 'reboot', '--firmware-setup'])
        print(json.dumps({"status": "ok", "action": action}))

    elif cmd == "get-system-info":
        print(json.dumps(get_system_info()))

    elif cmd == "get-binds":
        print(json.dumps(get_niri_binds()))

    elif cmd == "caffeine-status":
        # Check if inhibitor is active
        res = subprocess.run("pgrep -f 'systemd-inhibit.*simple-bar-caffeine'", shell=True, capture_output=True)
        active = res.returncode == 0
        print(json.dumps({"active": active}))

    elif cmd == "caffeine-toggle":
        res = subprocess.run("pgrep -f 'systemd-inhibit.*simple-bar-caffeine'", shell=True, capture_output=True)
        if res.returncode == 0:
            subprocess.run("pkill -f 'systemd-inhibit.*simple-bar-caffeine'", shell=True)
            print(json.dumps({"active": False}))
        else:
            subprocess.Popen("systemd-inhibit --what=idle:sleep --who=simple-bar-caffeine --why='User requested caffeine' sleep infinity", shell=True, start_new_session=True)
            print(json.dumps({"active": True}))

    elif cmd == "get-wallpapers":
        if theme:
            folder = sys.argv[2] if len(sys.argv) > 2 else None
            print(json.dumps(theme.list_local_wallpapers(folder)))
        else:
            print(json.dumps([]))

    elif cmd == "set-wallpaper" and len(sys.argv) > 2:
        if theme:
            res = theme.set_wallpaper_image(sys.argv[2])
            print(json.dumps(res))
        else:
            print(json.dumps({"status": "error", "message": "Theme module unavailable"}))

    elif cmd == "random-wallpaper":
        if theme:
            res = theme.apply_random_wallpaper()
            print(json.dumps(res))
        else:
            print(json.dumps({"status": "error", "message": "Theme module unavailable"}))

    elif cmd == "search-wallhaven":
        if theme:
            q = sys.argv[2] if len(sys.argv) > 2 else ""
            s = sys.argv[3] if len(sys.argv) > 3 else "toplist"
            p = int(sys.argv[4]) if len(sys.argv) > 4 else 1
            print(json.dumps(theme.search_wallhaven(q, s, p)))
        else:
            print(json.dumps({"status": "error", "wallpapers": []}))

    elif cmd == "apply-wallhaven" and len(sys.argv) > 3:
        if theme:
            res = theme.download_and_apply_wallhaven(sys.argv[2], sys.argv[3])
            print(json.dumps(res))
        else:
            print(json.dumps({"status": "error", "message": "Theme module unavailable"}))

    elif cmd == "init-wallpaper":
        if theme:
            print(json.dumps(theme.init_wallpaper()))
        else:
            print(json.dumps({"status": "error", "message": "Theme module unavailable"}))

    elif cmd == "get-theme":
        if theme:
            if os.path.exists(theme.COLORS_PATH):
                with open(theme.COLORS_PATH, "r") as f:
                    content = f.read()
                    print(content)
                try:
                    data = json.loads(content)
                    theme.export_terminal_themes(data.get("colors", {}), data.get("wallpaper", ""))
                except Exception:
                    pass
            else:
                cur = theme.get_current_wallpaper()
                pal = theme.extract_palette(cur)
                theme.save_theme_tokens(pal, cur)
                print(json.dumps({"wallpaper": cur, "colors": pal}))
        else:
            print(json.dumps({"colors": {}}))

    elif cmd == "set-accent" and len(sys.argv) > 2:
        if theme:
            hex_code = sys.argv[2]
            cur = theme.get_current_wallpaper()
            cfg = theme.load_config()
            mode = cfg.get("theme_mode", "pitch_black")
            pal = theme.extract_palette(cur, mode=mode, custom_accent=hex_code)
            theme.save_theme_tokens(pal, cur)
            print(json.dumps({"status": "ok", "colors": pal}))
        else:
            print(json.dumps({"status": "error"}))

    elif cmd == "set-theme-mode" and len(sys.argv) > 2:
        if theme:
            mode = sys.argv[2]
            cfg = theme.load_config()
            cfg["theme_mode"] = mode
            theme.save_config(cfg)
            cur = theme.get_current_wallpaper()
            pal = theme.extract_palette(cur, mode=mode)
            theme.save_theme_tokens(pal, cur)
            print(json.dumps({"status": "ok", "mode": mode, "colors": pal}))
        else:
            print(json.dumps({"status": "error"}))

if __name__ == "__main__":
    main()
