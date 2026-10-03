#!/usr/bin/env python3
import sys
import subprocess
import json
import os
import glob
import time
import shlex
import re

CONFIG_PATH = os.path.expanduser("~/.config/quickshell/simple-bar/config.json")

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
    dirs = ['/usr/share/applications', os.path.expanduser('~/.local/share/applications')]
    for d in dirs:
        if not os.path.exists(d): continue
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
                                if 'Development' in v: cat = 'Development'
                                elif 'Network' in v or 'Web' in v: cat = 'Internet'
                                elif 'Audio' in v or 'Video' in v or 'Media' in v: cat = 'Media'
                                elif 'Office' in v: cat = 'Office'
                                elif 'System' in v or 'Settings' in v: cat = 'System'
                            elif k == 'NoDisplay' and v.lower() == 'true': nodisplay = True
                if name and exec_cmd and not nodisplay:
                    if name.lower() in seen: continue
                    seen.add(name.lower())
                    clean_exec = ' '.join([p for p in exec_cmd.split() if not p.startswith('%')])
                    icon_path = resolve_icon(icon)
                    apps.append({
                        'name': name,
                        'exec': clean_exec,
                        'icon': icon,
                        'icon_path': icon_path,
                        'comment': comment or cat,
                        'category': cat
                    })
            except Exception:
                pass
    apps.sort(key=lambda x: x['name'].lower())
    return apps

def stream_wm():
    def resolve_focused_icon(app_id):
        if not app_id: return ''
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
        bl_file = '/sys/class/backlight/intel_backlight/actual_brightness'
        max_file = '/sys/class/backlight/intel_backlight/max_brightness'
        has_bl = os.path.exists(bl_file) and os.path.exists(max_file)
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

    threading.Thread(target=monitor_audio, daemon=True).start()
    threading.Thread(target=monitor_brightness, daemon=True).start()

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

    # CPU & RAM
    cpu_pct = 0
    mem_used = "0 GB"
    mem_total = "0 GB"
    mem_pct = 0.0
    try:
        with open('/proc/meminfo') as f:
            lines = f.readlines()
        t = a = 0
        for l in lines:
            if 'MemTotal' in l: t = int(l.split()[1])
            elif 'MemAvailable' in l: a = int(l.split()[1])
        if t > 0:
            used = (t - a) / 1024 / 1024
            total = t / 1024 / 1024
            mem_pct = round((t - a) / t, 2)
            mem_used = f"{used:.1f} GB"
            mem_total = f"{total:.1f} GB"

        top_res = subprocess.run("top -bn1 | grep 'Cpu(s)' | awk '{print $2+$4}'", shell=True, capture_output=True, text=True, timeout=2)
        cpu_pct = round(float(top_res.stdout.strip() or 0))
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
        "mem": {
            "used": mem_used,
            "total": mem_total,
            "percent": mem_pct
        }
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

def main():
    if len(sys.argv) <= 1 or sys.argv[1] == "status":
        print(json.dumps(get_status()))
        return

    cmd = sys.argv[1]

    if cmd == "wm-stream":
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
            subprocess.Popen(exec_cmd, shell=True, start_new_session=True)
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

    elif cmd == "disconnect-wifi":
        subprocess.run(['nmcli', 'dev', 'disconnect', 'wlan0'], capture_output=True)
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
        if os.path.exists('/usr/bin/blueman-manager'):
            subprocess.Popen(['blueman-manager'])
        else:
            subprocess.Popen(['kitty', '-e', 'bluetoothctl'])

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
            subprocess.Popen(['swaylock', '-f'])
        elif action == "sleep":
            subprocess.Popen(['systemctl', 'suspend'])
        elif action == "reboot":
            subprocess.Popen(['systemctl', 'reboot'])
        elif action == "poweroff":
            subprocess.Popen(['systemctl', 'poweroff'])
        print(json.dumps({"status": "ok", "action": action}))

if __name__ == "__main__":
    main()
