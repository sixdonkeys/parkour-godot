#!/usr/bin/env python3
"""Fetch third-party assets listed in tools/assets.json into game/assets/
(git-ignored) and check them against tools/assets.lock.json (decision
asset-pipeline). First fetch of a file records its SHA-256 in the lock; every
later fetch must match it, so a fresh clone gets exactly the same files.

    python3 tools/fetch_assets.py            fetch what's missing, verify all
    python3 tools/fetch_assets.py --verify   only check what's on disk
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tools" / "assets.json"
LOCK = ROOT / "tools" / "assets.lock.json"
DEST = ROOT / "game" / "assets"
UA = {"User-Agent": "parkour-godot-assets/1.0"}


def get(url: str) -> bytes:
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
        return r.read()


def polyhaven_files(asset_id: str, kind: str, spec: dict) -> list[tuple[str, str]]:
    """(url, relative path under game/assets/polyhaven/<id>/) for one asset."""
    files = json.loads(get(f"https://api.polyhaven.com/files/{asset_id}"))
    res, fmt = spec["resolution"], spec["format"]
    out = []
    if kind == "textures":
        for m in spec["maps"]:
            if m in files and res in files[m] and fmt in files[m][res]:
                url = files[m][res][fmt]["url"]
                out.append((url, url.rsplit("/", 1)[1]))
    else:
        g = files["gltf"][res]["gltf"]
        out.append((g["url"], g["url"].rsplit("/", 1)[1]))
        for rel, inc in g.get("include", {}).items():
            out.append((inc["url"], rel))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    lock = json.loads(LOCK.read_text()) if LOCK.exists() else {}
    bad = 0
    for kind, spec in manifest["polyhaven"].items():
        for aid in spec["ids"]:
            base = DEST / "polyhaven" / aid
            entries = lock.get(f"polyhaven/{aid}")
            if entries is None:
                if a.verify:
                    print(f"missing lock: polyhaven/{aid}"); bad += 1; continue
                entries = [{"url": u, "path": p} for u, p in polyhaven_files(aid, kind, spec)]
            for e in entries:
                f = base / e["path"]
                if not f.exists() and not a.verify:
                    f.parent.mkdir(parents=True, exist_ok=True)
                    f.write_bytes(get(e["url"]))
                if not f.exists():
                    print(f"missing: {f.relative_to(ROOT)}"); bad += 1; continue
                h = hashlib.sha256(f.read_bytes()).hexdigest()
                if "sha256" not in e:
                    e["sha256"] = h
                elif e["sha256"] != h:
                    print(f"CHECKSUM MISMATCH: {f.relative_to(ROOT)}"); bad += 1
            lock[f"polyhaven/{aid}"] = entries
            print(f"ok polyhaven/{aid} ({len(entries)} files)")
    if not a.verify:
        LOCK.write_text(json.dumps(lock, indent=1, sort_keys=True) + "\n")
    print("all assets present and verified" if not bad else f"{bad} problems")
    if not bad and not a.verify:
        import subprocess
        subprocess.run([sys.executable, str(ROOT / "tools" / "set_imports.py")])
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
