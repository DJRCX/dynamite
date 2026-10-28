#!/usr/bin/env python3
"""Print the island spans (runs of near-black pixels) on one row of each screenshot.

Usage: spans.py <row-y> <png>...   e.g. spans.py 27 /tmp/dynamite-f*.png
Each output line: file  mtime  x0-x1(width) ...
"""
import os
import sys

from PIL import Image


def spans(path, row, threshold=12, min_width=4):
    with Image.open(path) as source:
        image = source.convert("RGB")
    if row < 0 or row >= image.height:
        raise ValueError(f"row {row} is outside image bounds (0–{image.height - 1}): {path}")
    width = image.width
    runs, start = [], None
    for x in range(width):
        r, g, b = image.getpixel((x, row))
        dark = max(r, g, b) <= threshold
        if dark and start is None:
            start = x
        elif not dark and start is not None:
            if x - start >= min_width:
                runs.append((start, x - 1))
            start = None
    if start is not None and width - start >= min_width:
        runs.append((start, width - 1))
    return runs


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: spans.py <row-y> <png>...")
    try:
        row = int(sys.argv[1])
    except ValueError:
        raise SystemExit("row-y must be an integer") from None
    for path in sys.argv[2:]:
        try:
            t = os.path.getmtime(path)
            text = " ".join(f"{a}-{b}({b - a + 1})" for a, b in spans(path, row))
        except (OSError, ValueError) as error:
            raise SystemExit(str(error)) from None
        print(f"{os.path.basename(path)}\t{t % 100:.3f}\t{text}")


if __name__ == "__main__":
    main()
