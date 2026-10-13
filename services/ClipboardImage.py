#!/usr/bin/env python3
"""Copy one cached clipboard image through wl-copy without text-encoding its bytes."""

import pathlib
import subprocess
import sys


def main() -> int:
    if len(sys.argv) != 3:
        return 2
    image_path = pathlib.Path(sys.argv[1])
    mime_type = sys.argv[2]
    if mime_type not in {"image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp"}:
        return 2
    subprocess.run(["wl-copy", "--type", mime_type], input=image_path.read_bytes(), check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
