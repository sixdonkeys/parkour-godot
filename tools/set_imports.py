#!/usr/bin/env python3
"""Set import settings on third-party textures under game/assets/ (decision
asset-pipeline): VRAM compression with mipmaps for everything drawn in 3D,
normal maps flagged as normal maps. Godot only applies these automatically
when it sees a texture used in a 3D material at import time, which textures
assigned to shaders from code never are. Run after fetching assets; the next
`godot --import` re-imports anything whose settings changed.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WANT = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0"}


def fix(p: Path) -> bool:
    t = p.read_text()
    if 'importer="texture"' not in t:
        return False
    want = dict(WANT)
    name = p.name.lower()
    if "nor_gl" in name or "_normal" in name or "_nor_" in name:
        want["compress/normal_map"] = "1"
    new = t
    for k, v in want.items():
        new = re.sub(rf"^{re.escape(k)}=.*$", f"{k}={v}", new, flags=re.M)
    if new != t:
        p.write_text(new)
        return True
    return False


def main() -> int:
    changed = sum(fix(p) for p in (ROOT / "game" / "assets").rglob("*.import"))
    print(f"import settings updated on {changed} textures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
