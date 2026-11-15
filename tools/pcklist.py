"""List every file packed into a Godot .pck (formats v2-v4), or a .pck embedded
at the end of an executable, or inside a macOS .zip / .app.

Format read from Godot 4.7.2 core/io/file_access_pack.cpp (see
docs/survey/asset-pipeline.md).
"""
from __future__ import annotations

import io
import struct
import sys
import zipfile
from pathlib import Path

MAGIC = 0x43504447  # "GDPC"
PACK_DIR_ENCRYPTED = 1 << 0
PACK_FILE_REMOVAL = 1 << 1  # PackFileFlags


def _find_start(f) -> int:
    f.seek(0)
    if struct.unpack("<I", f.read(4))[0] == MAGIC:
        return 0
    # Embedded: trailer is [u64 pck size][u32 magic] at the end of the file.
    f.seek(-4, io.SEEK_END)
    if struct.unpack("<I", f.read(4))[0] != MAGIC:
        raise ValueError("no Godot pack found")
    f.seek(-12, io.SEEK_END)
    size = struct.unpack("<Q", f.read(8))[0]
    f.seek(-12 - size, io.SEEK_END)
    start = f.tell()
    if struct.unpack("<I", f.read(4))[0] != MAGIC:
        raise ValueError("embedded pack header not found")
    return start


def list_pack(f) -> dict:
    start = _find_start(f)
    f.seek(start + 4)
    version, vmaj, vmin, vpat, flags = struct.unpack("<5I", f.read(20))
    if version not in (2, 3, 4):
        raise ValueError(f"unsupported pack version {version}")
    f.read(8)  # file_base
    if flags & PACK_DIR_ENCRYPTED:
        raise ValueError("encrypted pack directory")
    if version >= 3:
        dir_offset = struct.unpack("<Q", f.read(8))[0] + start
        f.seek(dir_offset)
    else:
        f.read(16 * 4)
    count = struct.unpack("<I", f.read(4))[0]
    files = []
    for _ in range(count):
        sl = struct.unpack("<I", f.read(4))[0]
        path = f.read(sl).split(b"\0", 1)[0].decode("utf-8")
        ofs, size = struct.unpack("<QQ", f.read(16))
        f.read(16)  # md5
        fflags = struct.unpack("<I", f.read(4))[0]
        if not fflags & PACK_FILE_REMOVAL:
            files.append({"path": path, "size": size})
    return {"pack_version": version, "engine": f"{vmaj}.{vmin}.{vpat}", "files": files}


def list_any(path: str | Path) -> dict:
    p = Path(path)
    if p.suffix == ".zip":
        with zipfile.ZipFile(p) as z:
            packs = [n for n in z.namelist() if n.endswith(".pck")]
            if not packs:
                raise ValueError("no .pck inside zip")
            with z.open(packs[0]) as zf:
                return {"inside": packs[0], **list_pack(io.BytesIO(zf.read()))}
    if p.is_dir():  # a .app bundle
        packs = list(p.rglob("*.pck"))
        if not packs:
            raise ValueError("no .pck inside bundle")
        with open(packs[0], "rb") as f:
            return {"inside": str(packs[0]), **list_pack(f)}
    with open(p, "rb") as f:
        return list_pack(f)


if __name__ == "__main__":
    info = list_any(sys.argv[1])
    for e in info["files"]:
        print(f'{e["size"]:>12}  {e["path"]}')
