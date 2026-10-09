#!/usr/bin/env python3
import glob, json, subprocess, sys
from pathlib import Path

script=Path(__file__).resolve().parents[1]/"scripts"/"palette.py"
files=[Path(p) for p in glob.glob(sys.argv[1] + "/*") if p.lower().endswith((".png",".jpg",".jpeg",".webp",".bmp"))][:10]
if len(files)<10: raise SystemExit(f"need 10 varied images; found {len(files)}")
def lum(h):
    c=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
    return sum(x*y for x,y in zip(c,(.2126,.7152,.0722)))
def ratio(a,b):
    x,y=sorted((lum(a),lum(b)),reverse=True); return (x+.05)/(y+.05)
for image in files:
    data=json.loads(subprocess.check_output([sys.executable,str(script),str(image)],text=True))
    assert ratio(data["onAccent"],data["accent"])>=4.5, image
    assert ratio(data["accent"],data["panel"])>=3, image
    assert ratio(data["text"],data["panel"])>=7, image
print(f"palette-check: contrast rules passed for {len(files)} images")
