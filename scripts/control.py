#!/usr/bin/env python3
import sys
import subprocess
import json
import os

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

    if cmd == "toggle-wifi":
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
