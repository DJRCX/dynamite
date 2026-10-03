#!/usr/bin/env python3
import sys
import subprocess
import json
import os
import glob
import time
import shlex

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

def get_installed_apps():
    icon_dirs = [
        '/usr/share/pixmaps',
        '/usr/share/icons/hicolor/scalable/apps',
        '/usr/share/icons/hicolor/48x48/apps',
        '/usr/share/icons/hicolor/128x128/apps',
        '/usr/share/icons/hicolor/256x256/apps',
        '/usr/share/icons/hicolor/32x32/apps',
        '/usr/share/icons/Adwaita/scalable/apps',
        '/usr/share/icons/breeze/apps/48'
    ]

    def resolve_icon(icon_name):
        if not icon_name: return ''
        if os.path.isabs(icon_name) and os.path.exists(icon_name): return icon_name
        for d in icon_dirs:
            for ext in ['', '.png', '.svg', '.xpm']:
                p = os.path.join(d, icon_name + ext)
                if os.path.exists(p): return p
        return ''

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
    state = {'focused_app': '', 'focused_app_name': '', 'focused_title': '', 'active_ws': 1, 'workspaces': [], 'windows': {}}
    
    def emit(ws_event=False):
        print(json.dumps({
            'type': 'wm',
            'focused_app': state['focused_app'],
            'focused_app_name': state['focused_app_name'],
            'focused_title': state['focused_title'],
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

if __name__ == "__main__":
    main()
