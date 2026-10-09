#!/usr/bin/env python3
"""Create a Dynamite theme JSON from a wallpaper. Pillow is used only off the QML hot path."""
import argparse, colorsys, json, os, tempfile
from collections import Counter
from PIL import Image

BASE = {
 "name":"wallpaper", "label":"From wallpaper", "accent":"#49E3AF", "accentContainer":"#205543", "onAccent":"#0B1A14",
 "island":"#000000", "panel":"#181614", "subpage":"#1F1D1B", "card":"#262220", "chip":"#322E2B", "raised":"#2A2623",
 "track":"#0D0B0A", "window":"#0A0806", "sidebar":"#070707", "group":"#141110", "field":"#1C1916", "control":"#1A1816",
 "switchOff":"#3B3734", "knob":"#F2EFEA", "text":"#EDE7DD", "textSecondary":"#A39B91", "textMuted":"#6B655E", "danger":"#E5534B",
 "preview":["#49E3AF", "#181614", "#EDE7DD", "#E5534B"]
}
def rgb(h): return tuple(int(h[i:i+2],16) for i in (1,3,5))
def hx(c): return '#%02X%02X%02X' % tuple(max(0,min(255,round(x))) for x in c)
def lum(c):
    vals=[v/255 for v in rgb(c)]; vals=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals]
    return sum(a*b for a,b in zip(vals,(.2126,.7152,.0722)))
def contrast(a,b):
    x,y=sorted((lum(a),lum(b)),reverse=True); return (x+.05)/(y+.05)
def main():
    p=argparse.ArgumentParser(); p.add_argument('image'); p.add_argument('--mode',default='pitch_black'); p.add_argument('--accent'); p.add_argument('--output'); a=p.parse_args()
    im=Image.open(a.image).convert('RGB'); im.thumbnail((160,90)); quantized=im.quantize(colors=24).convert('RGB')
    pixels=quantized.getdata() if not hasattr(quantized,"get_flattened_data") else quantized.get_flattened_data()
    colors=Counter(pixels)
    swatches=[hx(c) for c,_ in colors.most_common(6)]
    accent=a.accent or swatches[0]
    # Move monotonically toward the pole with stronger contrast against the panel.
    lighten=contrast('#FFFFFF',BASE['panel'])>contrast('#000000',BASE['panel'])
    for _ in range(100):
        if contrast(accent,BASE['panel'])>=3: break
        c=rgb(accent)
        accent=hx(tuple(v+(255-v)*.035 if lighten else v*.965 for v in c))
    on='#000000' if contrast(accent,'#000000')>=contrast(accent,'#FFFFFF') else '#FFFFFF'
    out=dict(BASE); out['accent']=accent; out['onAccent']=on; out['accentContainer']=accent; out['preview']=[accent,BASE['panel'],BASE['text'],BASE['danger']]; out['swatches']=swatches
    payload=json.dumps(out,indent=2)+"\n"
    if a.output:
        os.makedirs(os.path.dirname(a.output),exist_ok=True)
        fd,tmp=tempfile.mkstemp(prefix=".wallpaper-theme-",dir=os.path.dirname(a.output),text=True)
        with os.fdopen(fd,"w") as f: f.write(payload)
        os.replace(tmp,a.output)
    else: print(payload)
if __name__=='__main__': main()
