#!/usr/bin/env python3
"""Desert terrain generator (decision landforms). Run at build time:

    .local/venv/bin/python tools/gen/terrain.py --out game/look_slice/generated

Reads the USGS 3DEP tile named in tools/assets.json (fetched to tools/cache/),
crops the Sabino Canyon window, compresses it (horizontal x0.1, vertical
x0.18), resamples the 1 km roam square to 1 m, adds seeded slope-weighted
detail, bakes a sky-occlusion term, and writes:

  heights_roam.f32   1025 x 1025 float32, metres, row-major north to south, 1 m spacing
  ao_roam.png        sky visibility 0..255, same grid
  heights_far.f32    the wider window at 8 m spacing for the backdrop
  terrain.json       sizes, spacing, origin, seed, source and checksum

Same tile + same seed = same output on every machine.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SEED = 20261115
TILE = ROOT / "tools/cache/usgs/USGS_13_n33w111_20261027.tif"
TILE_SHA256 = "bdf3a0751fbc9d31c20b472498d7a6bf87146364b2f8de09787b9be96571505a"
# 10.24 km square centred on the Sabino Canyon mouth, so that at x0.1 it is
# exactly the 1024 m roam square and shares the backdrop's scale.
_C_LON, _C_LAT = -110.80, 32.325
_HALF_LON = 5120 / (111320 * np.cos(np.radians(_C_LAT)))
_HALF_LAT = 5120 / 110950
WINDOW = dict(lon_a=_C_LON - _HALF_LON, lon_b=_C_LON + _HALF_LON, lat_a=_C_LAT - _HALF_LAT, lat_b=_C_LAT + _HALF_LAT)
FAR_WINDOW = dict(lon_a=-110.98, lon_b=-110.68, lat_a=32.22, lat_b=32.48)
H_SCALE = 0.1
V_SCALE = 0.18
ROAM_M = 1024
FAR_STEP_M = 8.0


def read_tile():
    import tifffile
    with tifffile.TiffFile(TILE) as f:
        p = f.pages[0]
        tags = {t.name: t.value for t in p.tags.values()}
        a = p.asarray().astype(np.float64)
    tp, sc = tags["ModelTiepointTag"], tags["ModelPixelScaleTag"]
    return a, tp[3], tp[4], sc[0]


def crop(a, lon0, lat0, d, w):
    i0 = int(round((lat0 - w["lat_b"]) / d)); i1 = int(round((lat0 - w["lat_a"]) / d))
    j0 = int(round((w["lon_a"] - lon0) / d)); j1 = int(round((w["lon_b"] - lon0) / d))
    return a[i0:i1, j0:j1]


def resample(a, out_h, out_w):
    """Bicubic via Pillow on float32 (mode F)."""
    im = Image.fromarray(a.astype(np.float32), mode="F")
    return np.asarray(im.resize((out_w, out_h), Image.BICUBIC), dtype=np.float64)


def fractal(shape, rng, octaves=6, base_cells=8):
    """Seeded value-noise fBm on a grid, values about -1..1."""
    h, w = shape
    out = np.zeros(shape)
    amp, total = 1.0, 0.0
    cells = base_cells
    for _ in range(octaves):
        g = rng.standard_normal((cells + 1, cells + 1)).astype(np.float32)
        up = np.asarray(Image.fromarray(g, mode="F").resize((w, h), Image.BICUBIC), dtype=np.float64)
        out += amp * up
        total += amp
        amp *= 0.5
        cells *= 2
    return out / total


def slope_deg(h, step):
    gy, gx = np.gradient(h, step, step)
    return np.degrees(np.arctan(np.hypot(gx, gy)))


def sky_visibility(h, step, dirs=16, max_dist=64.0):
    """Fraction of the sky hemisphere visible from each point, by horizon
    scanning in `dirs` directions up to `max_dist` metres."""
    vis = np.zeros_like(h)
    steps = np.unique(np.geomspace(1, max_dist / step, 12).astype(int))
    for k in range(dirs):
        ang = 2 * np.pi * k / dirs
        dx, dy = np.cos(ang), np.sin(ang)
        horizon = np.zeros_like(h)
        for s in steps:
            ox, oy = int(round(dx * s)), int(round(dy * s))
            shifted = np.roll(np.roll(h, -oy, axis=0), -ox, axis=1)
            elev = np.arctan2(shifted - h, s * step)
            horizon = np.maximum(horizon, elev)
        vis += np.cos(horizon) ** 2
    return np.clip(vis / dirs, 0, 1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "game/look_slice/generated"))
    a = ap.parse_args()
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    sha = hashlib.sha256(TILE.read_bytes()).hexdigest()
    if sha != TILE_SHA256:
        raise SystemExit(f"tile checksum mismatch: {sha}")
    tile, lon0, lat0, d = read_tile()
    rng = np.random.default_rng(SEED)

    # Roam square: the window compressed to ~1 km, resampled to 1 m.
    w = crop(tile, lon0, lat0, d, WINDOW)
    base = w.min()
    roam = resample(w, ROAM_M + 1, ROAM_M + 1)
    roam = (roam - base) * V_SCALE
    s = slope_deg(roam, 1.0)
    rock = np.clip((s - 20) / 20, 0, 1)            # steep ground gets rocky relief
    flat = 1 - rock
    detail = fractal(roam.shape, rng, octaves=7, base_cells=16)
    ripples = fractal(roam.shape, rng, octaves=3, base_cells=128)
    roam = roam + detail * (0.15 + 0.6 * rock) + ripples * 0.05 * flat
    ao = sky_visibility(roam, 1.0)

    # Backdrop: the wider window, same compression, 8 m spacing.
    fw = crop(tile, lon0, lat0, d, FAR_WINDOW)
    far_w_m = fw.shape[1] * d * 111320 * np.cos(np.radians(32.3)) * H_SCALE
    far_h_m = fw.shape[0] * d * 110950 * H_SCALE
    far = resample(fw, int(far_h_m / FAR_STEP_M) + 1, int(far_w_m / FAR_STEP_M) + 1)
    far = (far - base) * V_SCALE

    roam.astype("<f4").tofile(out / "heights_roam.f32")
    far.astype("<f4").tofile(out / "heights_far.f32")
    Image.fromarray((ao * 255).astype(np.uint8)).save(out / "ao_roam.png")
    # Where the roam square sits inside the backdrop (metres from the backdrop's NW corner).
    off_x = (WINDOW["lon_a"] - FAR_WINDOW["lon_a"]) * 111320 * np.cos(np.radians(32.3)) * H_SCALE
    off_z = (FAR_WINDOW["lat_b"] - WINDOW["lat_b"]) * 110950 * H_SCALE
    meta = {
        "seed": SEED, "source": TILE.name, "source_sha256": sha,
        "window": WINDOW, "far_window": FAR_WINDOW, "h_scale": H_SCALE, "v_scale": V_SCALE,
        "roam": {"file": "heights_roam.f32", "size": [ROAM_M + 1, ROAM_M + 1], "step_m": 1.0,
                 "min": float(roam.min()), "max": float(roam.max())},
        "far": {"file": "heights_far.f32", "size": [far.shape[1], far.shape[0]], "step_m": FAR_STEP_M,
                "min": float(far.min()), "max": float(far.max()), "roam_offset_m": [off_x, off_z]},
        "ao": "ao_roam.png",
        "base_elevation_m": float(base),
    }
    (out / "terrain.json").write_text(json.dumps(meta, indent=2))
    print(json.dumps({k: meta[k] for k in ("roam", "far")}, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
