#!/usr/bin/env python3
"""Writes the metrics course and the fuzz instrument's hole fixture.

  python3 tools/gen/metrics_course.py

Output (format `metrics-course/1`, read by game/movement/fixtures/metrics_course.gd):
  docs/fixtures/metrics-course.json            flat ground with gaps, ledges, steps,
                                               slopes, walls, corners, beams, a thin deck,
                                               a height-map patch and moving surfaces,
                                               all in stepped, known sizes
  docs/fixtures/movement-fuzz-hole-course.json a floor with a deliberate hole and
                                               nothing under it
  docs/fixtures/movement-fuzz-solid-course.json the same floor with the hole filled
                                               (the fuzz proof's control)
  docs/fixtures/movement-fuzz-cell-course.json a closed cell a body cannot move in
                                               (the stuck detector's known answer)

Meters, +Y up. Ground top is y = 0. Measurement lanes run toward -Z.
Everything is arithmetic; no randomness.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
PIT_Y = -4.0          # top of the pit floor
KILL_Y = -12.0        # below this a body has fallen through the world
Z_NEAR, Z_FAR = 10.0, -62.0

GAPS = [3.0, 4.0, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5]
LEDGES = [0.4, 0.6, 0.8, 0.9, 1.0, 1.1, 1.2, 1.5, 2.0, 2.5, 3.0]
STEPS = [0.1, 0.2, 0.3, 0.35, 0.4, 0.5]
SLOPES = [15, 25, 35, 40, 45, 50, 60]
WALL_LENGTHS = [4.0, 6.0, 8.0, 10.0, 12.0]
CORNERS = [90, 60, 30]
BEAMS = [0.2, 0.4, 0.6, 1.0]

pieces: list[dict] = []
lanes: list[dict] = []
spawns: list[dict] = []
regions: list[dict] = []


def r(v: float) -> float:
    return round(float(v), 4)


def box(pid: str, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, tag: str, **extra) -> None:
    """A box from its extents."""
    pieces.append({"id": pid, "kind": "box", "tag": tag,
                   "center": [r((x0 + x1) / 2), r((y0 + y1) / 2), r((z0 + z1) / 2)],
                   "size": [r(abs(x1 - x0)), r(abs(y1 - y0)), r(abs(z1 - z0))], **extra})


def spawn(sid: str, x: float, y: float, z: float, yaw_deg: float = 0.0, on_mover: str | None = None) -> None:
    """A place to put a body. `on_mover` ties it to a moving surface: `pos` is
    then where the spawn is at world tick 0, and it rides with the surface."""
    s = {"id": sid, "pos": [r(x), r(y), r(z)], "yaw_deg": yaw_deg}
    if on_mover:
        s["on_mover"] = on_mover
    spawns.append(s)


def region(rid: str, x0: float, x1: float, z0: float, z1: float) -> None:
    regions.append({"id": rid, "x": [r(min(x0, x1)), r(max(x0, x1))], "z": [r(min(z0, z1)), r(max(z0, z1))]})


def ramp(pid: str, xc: float, width: float, z_front: float, rise: float, deg: float, y_base: float = 0.0,
         toward: int = -1, thickness: float = 0.5) -> float:
    """A ramp whose top surface starts at (z_front, y_base) and climbs `rise`
    going toward -Z (toward = -1) or +Z. Returns the z where it tops out."""
    th = math.radians(deg)
    run = rise / math.tan(th)
    length = rise / math.sin(th)
    z_top = z_front + toward * run
    # Unit normal of the top surface.
    n = (0.0, math.cos(th), -toward * math.sin(th))
    mid = (xc, y_base + rise / 2, (z_front + z_top) / 2)
    c = [mid[0], mid[1] - n[1] * thickness / 2, mid[2] - n[2] * thickness / 2]
    pieces.append({"id": pid, "kind": "box", "tag": "ramp", "center": [r(v) for v in c],
                   "size": [r(width), r(thickness), r(length)], "rot_deg": [r(-toward * deg), 0.0, 0.0],
                   "slope_deg": deg, "rise": rise})
    return z_top


# --- base, moat and outer walls -------------------------------------------------
X0, X1 = 0.0, 184.0
box("base", X0 - 6, X1 + 6, PIT_Y - 1, PIT_Y, Z_NEAR + 6, Z_FAR - 6, "pit-floor")
box("outer-west", X0 - 7, X0 - 6, PIT_Y, 8, Z_NEAR + 7, Z_FAR - 7, "outer-wall")
box("outer-east", X1 + 6, X1 + 7, PIT_Y, 8, Z_NEAR + 7, Z_FAR - 7, "outer-wall")
box("outer-north", X0 - 6, X1 + 6, PIT_Y, 8, Z_NEAR + 6, Z_NEAR + 7, "outer-wall")
box("outer-south", X0 - 6, X1 + 6, PIT_Y, 8, Z_FAR - 7, Z_FAR - 6, "outer-wall")

# --- row A: gaps ---------------------------------------------------------------
EDGE_Z = -35.0
box("gap-runup", 0, 50, PIT_Y, 0, Z_NEAR, EDGE_Z, "ground")
for i, w in enumerate(GAPS):
    xa, xb = 5.0 * i, 5.0 * i + 5.0
    box(f"gap-{w}-landing", xa, xb, PIT_Y, 0, EDGE_Z - w, Z_FAR, "ground")
    lanes.append({"id": f"gap-{w}", "kind": "gap", "value": w, "start": [r(xa + 2.5), 0.0, 6.0],
                  "edge_z": EDGE_Z, "far_z": r(EDGE_Z - w), "end_z": Z_FAR, "x": [xa, xb]})
    spawn(f"gap-{w}-landing", xa + 2.5, 0, EDGE_Z - w - 4, 180.0)
region("gap-runup", 0, 50, Z_NEAR, EDGE_Z)
region("gap-landings", 0, 50, EDGE_Z - 3, Z_FAR)
spawn("apron-gaps", 25, 0, 6)
spawn("gap-edge", 12.5, 0, EDGE_Z + 2)

# --- runway: flat ground, 72 m ------------------------------------------------
box("runway", 50, 56, PIT_Y, 0, Z_NEAR, Z_FAR, "ground")
lanes.append({"id": "flat", "kind": "flat", "value": 0.0, "start": [53.0, 0.0, 6.0], "jump_z": -34.0,
              "end_z": Z_FAR, "x": [50.0, 56.0]})
region("runway", 50, 56, Z_NEAR, Z_FAR)
spawn("apron-runway", 53, 0, 6)

# --- row B: ledges, steps, stairs, slopes --------------------------------------
box("field-b", 56, 120, PIT_Y, 0, Z_NEAR, Z_FAR, "ground")
region("field-b-apron", 56, 120, Z_NEAR, -14)
for i, h in enumerate(LEDGES):
    xc = 59.0 + 5.0 * i
    box(f"ledge-{h}", xc - 2, xc + 2, 0, h, -14, -18, "ledge")
    lanes.append({"id": f"ledge-{h}", "kind": "ledge", "value": h, "start": [r(xc), 0.0, 0.0],
                  "face_z": -14.0, "top_y": h, "x": [xc - 2, xc + 2]})
    spawn(f"ledge-{h}-top", xc, h, -16, 180.0)
region("ledges", 56, 120, -14, -22)
for i, s in enumerate(STEPS):
    xc = 59.0 + 5.0 * i
    box(f"step-{s}", xc - 2, xc + 2, 0, s, -30, -34, "step")
    lanes.append({"id": f"step-{s}", "kind": "step", "value": s, "start": [r(xc), 0.0, -23.0],
                  "face_z": -30.0, "top_y": s, "x": [xc - 2, xc + 2]})
# A staircase: 12 risers of 0.18 m, treads of 0.30 m, then a deck.
RISE, TREAD, NSTEPS = 0.18, 0.30, 12
for k in range(NSTEPS):
    box(f"stairs-{k + 1:02d}", 90, 94, 0, r(RISE * (k + 1)), r(-30 - TREAD * k), r(-30 - TREAD * NSTEPS - 4), "stairs")
lanes.append({"id": "stairs", "kind": "stairs", "value": RISE, "start": [92.0, 0.0, -23.0], "face_z": -30.0,
              "top_y": r(RISE * NSTEPS), "risers": NSTEPS, "tread": TREAD, "x": [90.0, 94.0]})
spawn("stairs-deck", 92, RISE * NSTEPS, -30 - TREAD * NSTEPS - 2, 180.0)
region("steps-and-stairs", 56, 120, -22, -38)
for i, deg in enumerate(SLOPES):
    xc = 59.0 + 5.0 * i
    z_top = ramp(f"slope-{deg}", xc, 4.0, -44.0, 2.5, deg)
    box(f"slope-{deg}-deck", xc - 2, xc + 2, 0, 2.5, z_top, z_top - 3, "ledge")
    lanes.append({"id": f"slope-{deg}", "kind": "slope", "value": deg, "start": [r(xc), 0.0, -38.5],
                  "face_z": -44.0, "top_y": 2.5, "top_z": r(z_top), "x": [xc - 2, xc + 2]})
    spawn(f"slope-{deg}-deck", xc, 2.5, z_top - 1.5, 180.0)
# Slope seams: a ridge (up 30 degrees then down) and beside it a valley floor between two ramps.
z_ridge = ramp("ridge-up", 97.0, 4.0, -44.0, 2.0, 30)
ramp("ridge-down", 97.0, 4.0, z_ridge - (2.0 / math.tan(math.radians(30))), 2.0, 30, toward=1)
spawn("ridge-top", 97, 2.05, z_ridge)
ramp("valley-a", 103.0, 4.0, -51.0, 2.0, 35, toward=1)
ramp("valley-b", 103.0, 4.0, -51.0, 2.0, 35, toward=-1)
spawn("valley-floor", 103, 0.05, -51)
region("slopes", 56, 120, -38, Z_FAR)
spawn("apron-field-b", 88, 0, 6)

# --- row C: walls, corners, beams, tower, thin deck, movers, height map ---------
box("field-c", 120, 184, PIT_Y, 0, Z_NEAR, Z_FAR, "ground")
for i, length in enumerate(WALL_LENGTHS):
    xc = 124.0 + 4.0 * i
    box(f"wall-{length}", xc - 0.2, xc + 0.2, 0, 3.5, -4, -4 - length, "wall", length=length, height=3.5)
    spawn(f"wall-{length}-side", xc + 1.2, 0, -5, 0.0)
region("walls", 120, 144, 0, -18)
for i, ang in enumerate(CORNERS):
    ax, az = 126.0 + 10.0 * i, -30.0
    half = math.radians(ang / 2)
    for side in (-1, 1):
        d = (side * math.sin(half), math.cos(half))
        pieces.append({"id": f"corner-{ang}-{'a' if side < 0 else 'b'}", "kind": "box", "tag": "wall",
                       "center": [r(ax + d[0] * 2.0), 1.5, r(az + d[1] * 2.0)], "size": [0.4, 3.0, 4.0],
                       "rot_deg": [0.0, r(side * ang / 2), 0.0], "corner_deg": ang})
    spawn(f"corner-{ang}-mouth", ax, 0, az + 3.0, 0.0)
region("corners", 120, 152, -22, -34)
for i, w in enumerate(BEAMS):
    xc = 156.0 + 3.0 * i
    box(f"beam-{w}", xc - w / 2, xc + w / 2, 0.6, 0.7, -4, -12, "beam", width=w)
    box(f"beam-{w}-stand-a", xc - 1, xc + 1, 0, 0.7, -2, -4, "ledge")
    box(f"beam-{w}-stand-b", xc - 1, xc + 1, 0, 0.7, -12, -14, "ledge")
    spawn(f"beam-{w}-stand", xc, 0.7, -3, 0.0)
region("beams", 152, 168, 0, -16)
box("tower", 170, 174, 0, 3.0, -4, -8, "tower")
spawn("tower-top", 172, 3.0, -6, 0.0)
box("thin-deck", 170, 176, 1.45, 1.5, -8, -14, "deck", thickness=0.05)
for k, (px, pz) in enumerate([(170.1, -13.9), (175.9, -13.9), (175.9, -8.1)]):
    box(f"thin-deck-post-{k + 1}", px - 0.1, px + 0.1, 0, 1.45, pz + 0.1, pz - 0.1, "post")
spawn("thin-deck", 173, 1.5, -11, 0.0)
region("tower-and-deck", 164, 184, 0, -18)
# Moving surfaces: places are pure functions of the world tick.
pieces.append({"id": "mover-slab", "kind": "mover", "tag": "mover", "center": [140.0, 0.15, -42.0],
               "size": [3.0, 0.3, 3.0], "travel": [10.0, 0.0, 0.0], "period_ticks": 720, "phase_ticks": 0})
pieces.append({"id": "mover-lift", "kind": "mover", "tag": "mover", "center": [168.4, -1.45, -6.0],
               "size": [3.0, 3.5, 3.0], "travel": [0.0, 2.7, 0.0], "period_ticks": 600, "phase_ticks": 0})
lanes.append({"id": "carry-slab", "kind": "carry", "value": 10.0, "mover": "mover-slab",
              "start": [140.0, 0.3, -42.0], "x": [138.0, 152.0]})
lanes.append({"id": "carry-lift", "kind": "carry", "value": 2.7, "mover": "mover-lift",
              "start": [168.4, 0.3, -6.0], "x": [166.0, 170.0]})
spawn("mover-slab-top", 140, 0.3, -42, 0.0, on_mover="mover-slab")
spawn("mover-lift-top", 168.4, 0.3, -6, 0.0, on_mover="mover-lift")
region("mover-slab", 136, 154, -36, -48)
# Height-map patch, 24 m on a side, 1 m cells; zero at its border so it meets the field.
N = 25
heights = []
for j in range(N):
    for i in range(N):
        u, v = i / (N - 1), j / (N - 1)
        window = math.sin(math.pi * u) * math.sin(math.pi * v)
        waves = (math.sin(2 * math.pi * 2.0 * u) * math.sin(2 * math.pi * 1.5 * v)) ** 2
        mound = math.exp(-(((u - 0.5) / 0.18) ** 2 + ((v - 0.5) / 0.18) ** 2))
        heights.append(round((1.6 * waves + 2.2 * mound) * window, 3))
pieces.append({"id": "heightmap", "kind": "heightfield", "tag": "terrain", "center": [170.0, 0.0, -46.0],
               "cells": [N, N], "cell": 1.0, "heights": heights})
max_slope = 0.0
for j in range(N):
    for i in range(N - 1):
        max_slope = max(max_slope, abs(heights[j * N + i + 1] - heights[j * N + i]))
for j in range(N - 1):
    for i in range(N):
        max_slope = max(max_slope, abs(heights[(j + 1) * N + i] - heights[j * N + i]))
pieces[-1]["max_height"] = max(heights)
pieces[-1]["max_slope_deg"] = round(math.degrees(math.atan(max_slope)), 1)
spawn("heightmap-mid", 170, max(heights) + 0.3, -46, 0.0)
spawn("heightmap-edge", 160, 0.6, -40, 0.0)
region("heightmap", 158, 182, -34, -58)
region("field-c-open", 120, 158, -34, Z_FAR)
spawn("apron-field-c", 150, 0, 6)

course = {
    "format": "metrics-course/1",
    "id": "metrics-course",
    "units": "meters; +Y up; ground top at y = 0; measurement lanes run toward -Z",
    "generator": "tools/gen/metrics_course.py",
    "kill_plane_y": KILL_Y,
    "pit_floor_y": PIT_Y,
    "expected_fall_below_y": -2.0,
    "bounds": {"min": [X0 - 7, KILL_Y, Z_FAR - 7], "max": [X1 + 7, 12.0, Z_NEAR + 7]},
    "stepped_sizes": {"gap_m": GAPS, "ledge_m": LEDGES, "step_m": STEPS, "slope_deg": SLOPES,
                      "wall_length_m": WALL_LENGTHS, "corner_deg": CORNERS, "beam_width_m": BEAMS,
                      "stairs": {"rise_m": RISE, "tread_m": TREAD, "risers": NSTEPS}},
    "pieces": pieces, "lanes": lanes, "spawns": spawns, "regions": regions,
}
out = ROOT / "docs" / "fixtures" / "metrics-course.json"
out.write_text(json.dumps(course, indent=1) + "\n")
print(f"{out.relative_to(ROOT)}: {len(pieces)} pieces, {len(lanes)} lanes, {len(spawns)} spawns; "
      f"height map max {max(heights)} m, steepest cell {pieces[[p['id'] for p in pieces].index('heightmap')]['max_slope_deg']} deg")

# --- the hole fixture: a floor with a 2 m square hole and nothing underneath -------
pieces, lanes, spawns, regions = [], [], [], []
box("floor-west", -6, -1, -0.5, 0, 6, -6, "ground")
box("floor-east", 1, 6, -0.5, 0, 6, -6, "ground")
box("floor-north", -1, 1, -0.5, 0, 6, 1, "ground")
box("floor-south", -1, 1, -0.5, 0, -1, -6, "ground")
box("wall-west", -7, -6, -0.5, 4, 7, -7, "outer-wall")
box("wall-east", 6, 7, -0.5, 4, 7, -7, "outer-wall")
box("wall-north", -6, 6, -0.5, 4, 7, 6, "outer-wall")
box("wall-south", -6, 6, -0.5, 4, -6, -7, "outer-wall")
for k, (sx, sz) in enumerate([(-4, 4), (4, 4), (4, -4), (-4, -4)]):
    spawn(f"corner-{k + 1}", sx, 0, sz, 0.0)
region("floor", -6, 6, 6, -6)
hole = {
    "format": "metrics-course/1",
    "id": "movement-fuzz-hole-course",
    "units": "meters; +Y up; floor top at y = 0",
    "generator": "tools/gen/metrics_course.py",
    "purpose": "Known answer for the fuzz instrument: a 12 m floor with a 2 m square hole at its center and nothing "
               "below it. A body that walks into the hole falls past the kill plane; the instrument must report it.",
    "kill_plane_y": KILL_Y,
    "pit_floor_y": None,
    "expected_fall_below_y": None,
    "hole": {"x": [-1.0, 1.0], "z": [-1.0, 1.0]},
    "bounds": {"min": [-7, KILL_Y, -7], "max": [7, 6.0, 7]},
    "pieces": pieces, "lanes": lanes, "spawns": spawns, "regions": regions,
}
out = ROOT / "docs" / "fixtures" / "movement-fuzz-hole-course.json"
out.write_text(json.dumps(hole, indent=1) + "\n")
print(f"{out.relative_to(ROOT)}: {len(pieces)} pieces")

# --- the control: the same floor with the hole filled ----------------------------
box("floor-center", -1, 1, -0.5, 0, 1, -1, "ground")
solid = dict(hole)
solid["id"] = "movement-fuzz-solid-course"
solid["purpose"] = ("Control for the fuzz instrument's proof: the hole fixture's floor with the hole filled. "
                    "The instrument must report no fall through the world here.")
solid["hole"] = None
solid["pieces"] = pieces
out = ROOT / "docs" / "fixtures" / "movement-fuzz-solid-course.json"
out.write_text(json.dumps(solid, indent=1) + "\n")
print(f"{out.relative_to(ROOT)}: {len(pieces)} pieces")

# --- the cell: a body (0.6 m across) shut in a space 0.604 m across ------------------
pieces, lanes, spawns, regions = [], [], [], []
INNER = 0.302          # half the cell's inside width; the body's radius is 0.3
box("floor", -3, 3, -0.5, 0, 3, -3, "ground")
box("cell-west", -INNER - 0.5, -INNER, 0, 2.2, INNER + 0.5, -INNER - 0.5, "wall")
box("cell-east", INNER, INNER + 0.5, 0, 2.2, INNER + 0.5, -INNER - 0.5, "wall")
box("cell-north", -INNER, INNER, 0, 2.2, INNER + 0.5, INNER, "wall")
box("cell-south", -INNER, INNER, 0, 2.2, -INNER, -INNER - 0.5, "wall")
box("cell-lid", -INNER - 0.5, INNER + 0.5, 1.86, 2.2, INNER + 0.5, -INNER - 0.5, "wall")
spawn("cell", 0, 0, 0, 0.0)
region("cell", -1, 1, 1, -1)
cell = {
    "format": "metrics-course/1", "id": "movement-fuzz-cell-course",
    "units": "meters; +Y up; floor top at y = 0", "generator": "tools/gen/metrics_course.py",
    "purpose": "Known answer for the fuzz instrument's stuck detector: a body 0.6 m across shut in a cell 0.604 m "
               "across with a lid 6 cm above its head. Whatever the input asks, it cannot move a centimeter "
               "sideways; the instrument must report stuck states.",
    "kill_plane_y": KILL_Y, "pit_floor_y": None, "expected_fall_below_y": None,
    "cell": {"inside_width_m": 2 * INNER, "lid_y": 1.86},
    "bounds": {"min": [-3, KILL_Y, -3], "max": [3, 4.0, 3]},
    "pieces": pieces, "lanes": lanes, "spawns": spawns, "regions": regions,
}
out = ROOT / "docs" / "fixtures" / "movement-fuzz-cell-course.json"
out.write_text(json.dumps(cell, indent=1) + "\n")
print(f"{out.relative_to(ROOT)}: {len(pieces)} pieces")
