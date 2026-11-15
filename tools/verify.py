#!/usr/bin/env python3
"""Verification tool (module `verify`), out-of-game half.

  verify.py run <preset.json> [--module M --round N] [--normal] [--out DIR] [--baseline PNG]
  verify.py prove <instrument|all> [--round N]
  verify.py build [--label NAME] [--module M --round N] [--only PRESET]
  verify.py window [--wm gnome|niri] [--round N]
  verify.py setup-check

Everything that draws must run outside the sandbox (no /dev/dri inside it).
See docs/decisions/verification-rendering.md and README.md.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import imgmetrics  # noqa: E402
import pcklist  # noqa: E402
import wavmetrics  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
DOCS = ROOT / "docs"
GODOT = os.environ.get("GODOT", "godot")
GODOT_VERSION = "4.7.2.stable"
ERR_RE = re.compile(r"^(ERROR|Error|SCRIPT ERROR|USER ERROR|SHADER ERROR|FATAL|CRASH)[: ]")
WARN_RE = re.compile(r"^(WARNING|USER WARNING|SCRIPT WARNING)[: ]")


# --- environment ---------------------------------------------------------------

def godot_env(extra: dict | None = None) -> dict:
    """Engine settings, caches, saved data and templates stay inside the project."""
    env = dict(os.environ)
    local = ROOT / ".local"
    env["XDG_CONFIG_HOME"] = str(local / "config")
    env["XDG_DATA_HOME"] = str(local / "data")
    env["XDG_CACHE_HOME"] = str(local / "cache")
    for k in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
        Path(env[k]).mkdir(parents=True, exist_ok=True)
    if extra:
        env.update(extra)
    return env


def git_commit() -> str:
    try:
        h = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        dirty = subprocess.run(["git", "diff", "--quiet", "HEAD", "--", "game", "tools"], cwd=ROOT).returncode != 0
        return h + ("-dirty" if dirty else "")
    except Exception:
        return "unknown"


def ensure_imported() -> None:
    """Import every run: it registers new global class names and new assets,
    and is quick when nothing changed."""
    subprocess.run([GODOT, "--headless", "--path", str(GAME), "--import"], env=godot_env(),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900)


def scan_output(text: str) -> dict:
    lines = text.splitlines()
    errs, warns = [], []
    for i, ln in enumerate(lines):
        if ERR_RE.match(ln):
            errs.append(ln + (" | " + lines[i + 1].strip() if i + 1 < len(lines) else ""))
        elif WARN_RE.match(ln):
            warns.append(ln + (" | " + lines[i + 1].strip() if i + 1 < len(lines) else ""))
    return {"errors": errs, "warnings": warns}


def evidence_dir(module: str, rnd: int, *parts: str) -> Path:
    d = DOCS / "evidence" / module / f"round-{rnd}"
    for p in parts:
        d = d / p
    d.mkdir(parents=True, exist_ok=True)
    return d


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, default=_json_default) + "\n")


def _json_default(o):
    if isinstance(o, (np.floating,)):
        return float(o)
    if isinstance(o, (np.integer,)):
        return int(o)
    return str(o)


# --- run one preset --------------------------------------------------------------

def run_preset(preset: Path, out: Path, test_mode=True, baseline: Path | None = None,
               timeout=1800, extra_env: dict | None = None, wrap: list[str] | None = None,
               join_wrapped=False, driver: str | None = None, fullscreen: bool | None = None,
               engine_args: list[str] | None = None) -> dict:
    preset = preset.resolve()
    out = out.resolve()
    if fullscreen is None:
        # Benchmarks run fullscreen unless the preset is about the window itself.
        fullscreen = json.loads(preset.read_text()).get("resolution", "window") != "window"
    out.mkdir(parents=True, exist_ok=True)
    ensure_imported()
    commit = git_commit()
    cmd = [GODOT, "--path", str(GAME), "--disable-vsync"] + (engine_args or [])
    if test_mode:
        cmd += ["--fixed-fps", "60"]
    cmd += ["--", "--preset", str(preset), "--out", str(out), "--commit", commit, "--repo-root", str(ROOT)]
    if test_mode:
        cmd.append("--test-mode")
    if fullscreen:
        cmd.append("--bench-fullscreen")
    if wrap and join_wrapped:
        import shlex
        cmd = wrap + [" ".join(shlex.quote(c) for c in [sys.executable, driver] + cmd)]
    elif wrap:
        cmd = wrap + cmd
    t0 = dt.datetime.now()
    rc, text, hang = run_engine(cmd, godot_env(extra_env), out / "engine-output.txt", timeout)
    logp = out / "log.json"
    log = json.loads(logp.read_text()) if logp.exists() else {"missing_log": True}
    scanned = scan_output(text)
    in_game_errors = log.get("engine", {}).get("errors", [])
    expected = json.loads(preset.read_text()).get("expect_errors", [])
    if expected:
        def is_expected(msg: str) -> bool:
            return any(e in msg for e in expected)
        log["expected_errors_seen"] = [e for e in in_game_errors if is_expected(e.get("message", ""))]
        in_game_errors = [e for e in in_game_errors if not is_expected(e.get("message", ""))]
        scanned["expected"] = [e for e in scanned["errors"] if is_expected(e)]
        scanned["errors"] = [e for e in scanned["errors"] if not is_expected(e)]
        log["expected_errors_missing"] = [e for e in expected
                                          if not any(e in x.get("message", "") for x in log["expected_errors_seen"])]
    log["orchestrator"] = {
        "command": cmd, "exit_code": rc, "started": t0.isoformat(), "shutdown_hang": hang,
        "self_terminated": "self-terminated after flush" in text,
        "seconds": (dt.datetime.now() - t0).total_seconds(),
        "output_errors": scanned["errors"], "output_warnings": scanned["warnings"],
        "error_count": len(scanned["errors"]) + len(in_game_errors) + (1 if log.get("missing_log") else 0) + (1 if hang else 0)
                       + len(log.get("expected_errors_missing", [])),
        "verify_tool_commit": commit,
    }
    m = log.get("machine", {})
    log["orchestrator"]["frame_numbers_count"] = not m.get("software_renderer", True)
    p = json.loads(preset.read_text())
    still = out / "still.png"
    if still.exists():
        img = imgmetrics.load_rgb(still)
        log["image"] = {"size": [img.shape[1], img.shape[0]]}
        base = baseline or find_baseline(p.get("id", preset.stem), out)
        if base and base.exists():
            b = imgmetrics.load_rgb(base)
            if b.shape == img.shape:
                log["image"]["ssim_vs_baseline"] = imgmetrics.ssim(img, b)
            else:
                log["image"]["ssim_vs_baseline"] = None
                log["image"]["ssim_note"] = f"baseline size {b.shape[1]}x{b.shape[0]} differs"
            log["image"]["baseline"] = str(base.relative_to(ROOT))
        else:
            log["image"]["ssim_vs_baseline"] = None
            log["image"]["ssim_note"] = "no earlier round of this preset"
        look = p.get("look")
        if look:
            log["image"]["reference_distance"] = reference_distance(img, look)
    wav = out / "audio.wav"
    if wav.exists():
        log["sound_file_check"] = wavmetrics.measure(wav)
    write_json(logp, log)
    return log


def _thread_dump(pid: int) -> list[dict]:
    """Which threads a stuck engine is waiting in (Linux /proc), for diagnosis."""
    res = []
    for task in Path(f"/proc/{pid}/task").glob("*"):
        try:
            res.append({"tid": task.name, "comm": (task / "comm").read_text().strip(),
                        "wchan": (task / "wchan").read_text().strip(),
                        "state": (task / "stat").read_text().split()[2]})
        except OSError:
            pass
    return res


def run_engine(cmd, env, log_path: Path, timeout: int, grace=15.0):
    """Run the engine with output streamed to a file. If it is still alive
    `grace` seconds after printing VERIFY done, record its threads and kill it."""
    import time
    with open(log_path, "w") as lf:
        proc = subprocess.Popen(cmd, env=env, stdout=lf, stderr=subprocess.STDOUT, text=True)
        start = time.monotonic()
        done_at = None
        hang = None
        while proc.poll() is None:
            time.sleep(0.5)
            if done_at is None and "VERIFY done" in log_path.read_text(errors="ignore"):
                done_at = time.monotonic()
            late = done_at is not None and time.monotonic() - done_at > grace
            if late or time.monotonic() - start > timeout:
                hang = {"after": "VERIFY done" if late else "timeout",
                        "threads": _thread_dump(proc.pid) if sys.platform.startswith("linux") else []}
                proc.kill()
                proc.wait()
                break
    text = log_path.read_text(errors="ignore")
    # Always written (null when the engine exited by itself), so an old hang
    # record never outlives the run that made it.
    log_path.with_name("engine-hang.json").write_text(json.dumps(hang, indent=1) + "\n")
    return proc.returncode, text, hang


def find_baseline(preset_id: str, out: Path) -> Path | None:
    """The same preset's still from the most recent earlier round folder."""
    cands = []
    for s in (DOCS / "evidence").glob(f"*/round-*/{preset_id}/still.png"):
        if s.parent.resolve() == out.resolve():
            continue
        if s.stat().st_mtime < (out / "log.json").stat().st_mtime if (out / "log.json").exists() else True:
            cands.append(s)
    return max(cands, key=lambda s: s.stat().st_mtime) if cands else None


def reference_distance(img: np.ndarray, look: dict) -> dict:
    folder = ROOT / "reference" / look["environment"] / look["view"] / look["time"]
    photos = sorted([p for p in folder.glob("*") if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".tif", ".tiff")])
    res = []
    for ph in photos:
        r = imgmetrics.load_rgb(ph)
        d = imgmetrics.hist_distance(img, r)
        res.append({"photo": str(ph.relative_to(ROOT)), **d})
    if not res:
        return {"folder": str(folder.relative_to(ROOT)), "photos": 0, "note": "no reference photographs"}
    return {"folder": str(folder.relative_to(ROOT)), "photos": len(res),
            "luma_tv_mean": float(np.mean([r["luma_tv"] for r in res])),
            "rgb_tv_mean": float(np.mean([r["rgb_tv"] for r in res])),
            "per_photo": res, "note": "coarse signal; gates nothing"}


# --- proofs on known-answer fixtures ---------------------------------------------

FIX = DOCS / "fixtures"


def _tmp_preset(name: str, data: dict, rnd: int) -> Path:
    d = evidence_dir("verify", rnd, "proofs", "presets")
    p = d / f"{name}.json"
    write_json(p, data)
    return p


def prove_frametime(rnd: int) -> dict:
    """A frame limiter at a known rate: 30 fps -> 33.3 ms frames."""
    p = FIX / "verify-frametime-limiter-30.json"
    out = evidence_dir("verify", rnd, "proofs", "frametime")
    log = run_preset(p, out, test_mode=False)
    ft = log.get("frame_time", {}).get("frame_ms", {})
    p50 = ft.get("p50")
    ok = p50 is not None and abs(p50 - 1000 / 30) <= 1.5 and log["orchestrator"]["error_count"] == 0
    return {"instrument": "frame time", "fixture": str(p.relative_to(ROOT)),
            "expected_p50_ms": round(1000 / 30, 3), "tolerance_ms": 1.5,
            "measured_p50_ms": p50, "measured": ft, "pass": ok, "log": str((out / "log.json").relative_to(ROOT))}


def prove_memory(rnd: int) -> dict:
    """A texture of known size: 4096x4096 RGBA8 without mipmaps = 67,108,864 bytes."""
    p = FIX / "verify-memory-known-texture.json"
    out = evidence_dir("verify", rnd, "proofs", "memory")
    log = run_preset(p, out)
    mem = log.get("memory", {})
    exp = 4096 * 4096 * 4
    tex = mem.get("texture_delta_load_bytes")
    r = mem.get("readings", [{}, {}, {}])
    tex_back = r[2].get("texture_bytes") == r[0].get("texture_bytes")
    ok = (tex is not None and abs(tex - exp) <= 0.05 * exp and tex_back
          and mem.get("returns_within_5pct") is True and mem.get("grows_each_cycle") is False
          and log["orchestrator"]["error_count"] == 0)
    return {"instrument": "memory", "fixture": str(p.relative_to(ROOT)), "expected_texture_delta_bytes": exp,
            "measured_texture_delta_bytes": tex, "video_delta_bytes": mem.get("video_delta_load_bytes"),
            "unload_return_ratio_raw": mem.get("unload_return_ratio"),
            "warm_return_ratio": mem.get("warm_return_ratio"), "grows_each_cycle": mem.get("grows_each_cycle"),
            "texture_returns_exactly": tex_back,
            "readings": mem.get("readings"), "pass": ok, "log": str((out / "log.json").relative_to(ROOT))}


def prove_sound(rnd: int) -> dict:
    """A tone of known level: amplitude 0.5 -> peak -6.02 dBFS, RMS -9.03 dBFS;
    amplitude 1.25 -> clipping detected."""
    res = {"instrument": "sound", "cases": []}
    ok = True
    for name, amp in (("verify-sound-tone-minus6", 0.5), ("verify-sound-tone-clipping", 1.25)):
        p = FIX / f"{name}.json"
        out = evidence_dir("verify", rnd, "proofs", name)
        log = run_preset(p, out)
        s = log.get("sound", {})
        f = log.get("sound_file_check", {})
        exp_peak = 20 * np.log10(amp)
        # The steady part of the tone: generator start-up can leave a short gap,
        # so RMS is checked from the file's own steady section below.
        case = {"fixture": str(p.relative_to(ROOT)), "amplitude": amp, "expected_peak_dbfs": round(float(exp_peak), 3),
                "measured_peak_dbfs": s.get("peak_dbfs"), "file_peak_dbfs": f.get("peak_dbfs"),
                "clipped_samples": s.get("clipped_samples"), "seconds": s.get("seconds"),
                "driver": s.get("driver"), "log": str((out / "log.json").relative_to(ROOT))}
        wavp = out / "audio.wav"
        if wavp.exists():
            arr, rate = wavmetrics.read_wav(wavp)
            mid = arr[len(arr) // 4: 3 * len(arr) // 4]
            case["steady_rms_dbfs"] = wavmetrics.db(float(np.sqrt(np.mean(mid ** 2)))) if mid.size else None
            case["expected_rms_dbfs"] = round(float(exp_peak - 3.0103), 3)
        if amp < 1.0:
            c_ok = (s.get("peak_dbfs") is not None and abs(s["peak_dbfs"] - exp_peak) <= 0.2
                    and s.get("clipped_samples") == 0 and case.get("steady_rms_dbfs") is not None
                    and abs(case["steady_rms_dbfs"] - case["expected_rms_dbfs"]) <= 0.3)
        else:
            c_ok = (s.get("clipped_samples") or 0) > 0 and abs((s.get("peak_dbfs") or -99) - exp_peak) <= 0.2
        c_ok = c_ok and log["orchestrator"]["error_count"] == 0
        case["pass"] = bool(c_ok)
        ok = ok and c_ok
        res["cases"].append(case)
    res["pass"] = ok
    return res


def prove_image(rnd: int) -> dict:
    """An image against itself, and against copies altered by known amounts."""
    rng = np.random.default_rng(7)
    base = rng.integers(0, 256, size=(240, 320, 3)).astype(np.float64)
    self_ssim = imgmetrics.ssim(base, base)
    self_tv = imgmetrics.hist_distance(base, base)
    # Uniform grey 100 vs grey 120: sigma terms vanish, SSIM = luminance term.
    g1 = np.full((64, 64, 3), 100.0)
    g2 = np.full((64, 64, 3), 120.0)
    mu1, mu2 = 100.0, 120.0
    expected_offset = (2 * mu1 * mu2 + imgmetrics.C1) / (mu1 ** 2 + mu2 ** 2 + imgmetrics.C1)
    got_offset = imgmetrics.ssim(g1, g2)
    # A quarter of a uniform grey image set to black moves exactly 25% of the mass.
    q = g1.copy()
    q[:32, :32] = 0
    tvq = imgmetrics.hist_distance(g1, q)
    cases = {
        "self_ssim": {"expected": 1.0, "got": self_ssim, "pass": abs(self_ssim - 1) < 1e-12},
        "self_hist": {"expected": 0.0, "got": self_tv, "pass": self_tv["luma_tv"] == 0 and self_tv["rgb_tv"] == 0},
        "grey_offset_ssim": {"expected": expected_offset, "got": got_offset, "pass": abs(got_offset - expected_offset) < 1e-9},
        "quarter_black_hist": {"expected": 0.25, "got": tvq, "pass": abs(tvq["luma_tv"] - 0.25) < 1e-12 and abs(tvq["rgb_tv"] - 0.25) < 1e-12},
    }
    return {"instrument": "image numbers", "cases": cases, "pass": all(c["pass"] for c in cases.values())}


def prove_build(rnd: int) -> dict:
    """A package holding a file of known size and one planted file ASSETS.md doesn't list."""
    fx = FIX / "buildcheck"
    known = fx / "data" / "known_size.bin"
    planted = fx / "assets" / "planted.bin"
    known.parent.mkdir(parents=True, exist_ok=True)
    planted.parent.mkdir(parents=True, exist_ok=True)
    size = 10 * 1024 * 1024
    known.write_bytes(np.random.default_rng(11).integers(0, 256, size, dtype=np.uint8).tobytes())
    planted.write_bytes(b"planted file with no ASSETS.md entry\n")
    out = evidence_dir("verify", rnd, "proofs", "build")
    dest = ROOT / "builds" / "fixture-buildcheck" / "linux-arm64" / "buildcheck.arm64"
    r = export_one(fx, "Linux arm64", dest)
    listing = check_pack(dest.with_suffix(".pck"), fx, fx / "ASSETS.md")
    found = [f for f in listing["files"] if f["path"].endswith("data/known_size.bin")]
    flagged = [f for f in listing["unlisted"] if f.endswith("assets/planted.bin")]
    ok = r["ok"] and len(found) == 1 and found[0]["size"] == size and len(flagged) == 1
    rep = {"instrument": "build size and packed-file list", "export": r,
           "expected_known_size": size, "found_known": found, "unlisted": listing["unlisted"],
           "planted_flagged": bool(flagged), "pass": ok}
    write_json(out / "build-proof.json", rep)
    return rep


def prove_window(rnd: int) -> dict:
    """Window sequence on an empty scene under the live window manager, plus the
    interface check on a fixture with one element outside the window."""
    out = evidence_dir("verify", rnd, "proofs", "window")
    log = run_preset(FIX / "verify-window-sequence-empty.json", out / "sequence")
    seq = log.get("window_sequence", [])
    obs = [s.get("observed", {}) for s in seq]
    fills = all(o.get("fills_without_stretch", False) for o in obs if "window_size" in o)
    errors = log["orchestrator"]["error_count"]
    log2 = run_preset(FIX / "verify-window-ui-outside.json", out / "ui-outside")
    outside = log2.get("interface_outside", [])
    ui_ok = len(outside) == 1 and outside[0]["path"].endswith("Outside")
    return {"instrument": "window", "wm": log.get("window_wm"), "steps": seq,
            "zero_errors": errors == 0, "fills_without_stretch": fills,
            "ui_outside_fixture": {"expected": 1, "found": outside, "pass": ui_ok},
            "note": "GNOME: the harness resizes the window itself and sends synthetic focus events; see decision windowing",
            "pass": errors == 0 and fills and ui_ok and len(obs) == len(seq) and len(seq) > 0}


WM_WRAP = {
    "niri": ["niri", "-c", str(ROOT / "tools" / "wm" / "niri-test.kdl"), "--",
             sys.executable, str(ROOT / "tools" / "wm" / "drive_niri.py")],
    # Umbriel's -s takes one shell command string; built in window_test().
    "umbriel": ["umbriel", "-c", str(ROOT / "tools" / "wm" / "umbriel-test.toml"), "-s"],
}


def window_test(wm: str, rnd: int) -> dict:
    """The window sequence under a named window manager, nested in a window."""
    preset = DOCS / "presets" / f"verify-window-sequence-{wm}.json"
    out = evidence_dir("verify", rnd, f"window-{wm}")
    drv = out / "driver-output.txt"
    drv.write_text("")
    log = run_preset(preset, out, wrap=WM_WRAP[wm], extra_env={"NIRI_CONFIG": "", "VERIFY_DRIVER_LOG": str(drv)},
                     join_wrapped=(wm == "umbriel"),
                     driver=str(ROOT / "tools" / "wm" / "drive_umbriel.py") if wm == "umbriel" else None)
    seq = log.get("window_sequence", [])
    obs = [s.get("observed", {}) for s in seq]
    text = drv.read_text(errors="ignore")
    log["orchestrator"]["output_errors"] += scan_output(text)["errors"]
    log["orchestrator"]["error_count"] += len(scan_output(text)["errors"])
    return {"wm": wm, "driver_lines": [l for l in text.splitlines() if l.startswith("DRIVER")],
            "steps": [{"name": s.get("name"), **{k: s.get("observed", {}).get(k) for k in
                       ("window_size", "window_mode", "frame_pixels", "fills_without_stretch", "pointer_released", "paused")}}
                      for s in seq],
            "focus_events": log.get("focus_events", []),
            "zero_errors": log["orchestrator"]["error_count"] == 0,
            "fills_without_stretch": all(o.get("fills_without_stretch", False) for o in obs),
            "driver_commands_ok": all(l.rstrip().endswith("-> 0") for l in text.splitlines() if "->" in l),
            "shapes_distinct": len({str(o.get("window_size")) for o in obs[:3]}) == 3,
            "focus_lost_and_regained": any(f["event"] == "app_focus_out" for f in log.get("focus_events", []))
                    and sum(f["event"] == "app_focus_in" for f in log.get("focus_events", [])) >= 2,
            "pass": log["orchestrator"]["error_count"] == 0 and len(obs) == len(seq) > 0
                    and all(o.get("fills_without_stretch", False) for o in obs)
                    and all(l.rstrip().endswith("-> 0") for l in text.splitlines() if "->" in l)
                    and len({str(o.get("window_size")) for o in obs[:3]}) == 3}


PROOFS = {"image": prove_image, "frametime": prove_frametime, "memory": prove_memory,
          "sound": prove_sound, "build": prove_build, "window": prove_window}


# --- build step ----------------------------------------------------------------

PRESETS = {"macOS": "macos/Ridgeline.zip", "Linux arm64": "linux-arm64/Ridgeline.arm64",
           "Linux x86_64": "linux-x86_64/Ridgeline.x86_64", "Windows x86_64": "windows-x86_64/Ridgeline.exe"}


def export_one(project: Path, preset: str, dest: Path) -> dict:
    dest.parent.mkdir(parents=True, exist_ok=True)
    cmd = [GODOT, "--headless", "--path", str(project), "--export-release", preset, str(dest)]
    proc = subprocess.run(cmd, env=godot_env(), capture_output=True, text=True, timeout=1800)
    text = proc.stdout + "\n" + proc.stderr
    sc = scan_output(text)
    exists = dest.exists()
    return {"preset": preset, "path": str(dest.relative_to(ROOT)), "exit_code": proc.returncode,
            "errors": sc["errors"], "warnings": sc["warnings"], "exists": exists,
            "ok": proc.returncode == 0 and exists and not sc["errors"]}


def size_of(p: Path) -> int:
    if p.is_dir():
        return sum(f.stat().st_size for f in p.rglob("*") if f.is_file())
    return p.stat().st_size if p.exists() else -1


OWN_DIRS = ("core/", "movement/", "traversal/", "camera/", "character/", "kit/", "rules/", "interface/",
            "verify/", "profiles/", "look_slice/", "desert_course/", "desert_dress/", "mountain_course/",
            "mountain_dress/", "chicago_course/", "chicago_dress/", "newyork_course/", "newyork_dress/",
            "data/", "main/")
THIRD_DIRS = ("assets/", "thirdparty/")


def assets_paths(assets_md: Path) -> list[str]:
    """Paths listed in ASSETS.md entries as `**Path:** `game/...`` (or a folder ending in /)."""
    if not assets_md.exists():
        return []
    paths = []
    for m in re.finditer(r"\*\*Path:\*\*\s*(.+)", assets_md.read_text()):
        for q in re.findall(r"`([^`]+)`", m.group(1)):
            paths.append(q.removeprefix("game/").removeprefix("res://"))
    return paths


def import_sources(project: Path) -> dict:
    """Map imported resource paths (.godot/imported/...) back to their source file."""
    mp = {}
    for imp in project.rglob("*.import"):
        if ".godot" in imp.parts:
            continue
        src = str(imp.relative_to(project))[: -len(".import")]
        for m in re.finditer(r'"?(?:path[.\w]*|dest_files)"?\s*=\s*(.*)', imp.read_text()):
            for q in re.findall(r'res://(\.godot/imported/[^"]+)', m.group(1)):
                mp[q] = src
    return mp


def check_pack(pack: Path, project: Path, assets_md: Path) -> dict:
    info = pcklist.list_any(pack)
    listed = assets_paths(assets_md)
    imports = import_sources(project)
    # Scenes converted at export land in .godot/exported/<id>/export-<hash>-<name>.scn;
    # map them back to their source scene by name so a third-party scene can't
    # pass as own work.
    scenes = {}
    for sc in list(project.rglob("*.tscn")) + list(project.rglob("*.scn")):
        if ".godot" not in sc.parts:
            scenes.setdefault(sc.stem, []).append(str(sc.relative_to(project)))
    unlisted, own, third = [], [], []
    for f in info["files"]:
        path = f["path"].removeprefix("res://")
        src = imports.get(path, path)
        m = re.match(r"\.godot/exported/[^/]+/export-[0-9a-f]+-(.+)\.scn$", path)
        if m:
            cands = scenes.get(m.group(1), [])
            third_c = [c for c in cands if c.startswith(THIRD_DIRS)]
            src = third_c[0] if third_c else (cands[0] if cands else path)
        if src.endswith(".import"):
            src = src[: -len(".import")]
        if src.endswith(".remap"):
            src = src[: -len(".remap")]
        f["source"] = src
        if src.startswith(THIRD_DIRS):
            if any(src == l or (l.endswith("/") and src.startswith(l)) for l in listed):
                third.append(src)
            else:
                unlisted.append(src)
        elif src.startswith(OWN_DIRS) or src.startswith(".godot/") or "/" not in src:
            own.append(src)
        else:
            unlisted.append(src)
    return {**info, "own_work": sorted(set(own)), "listed_third_party": sorted(set(third)),
            "unlisted": sorted(set(unlisted))}


def stage_bench_presets() -> list[str]:
    dest = GAME / "verify" / "bench_presets"
    dest.mkdir(parents=True, exist_ok=True)
    staged = []
    for p in sorted((DOCS / "presets").glob("*.json")):
        d = json.loads(p.read_text())
        if d.get("bench"):
            if "camera_path" in d and not str(d["camera_path"]).startswith("res://"):
                cp = ROOT / d["camera_path"]
                (dest / "paths").mkdir(exist_ok=True)
                (dest / "paths" / cp.name).write_text(cp.read_text())
                d["camera_path"] = f"res://verify/bench_presets/paths/{cp.name}"
            (dest / p.name).write_text(json.dumps(d, indent=2))
            staged.append(p.name)
    # The runner reads only what this index lists, so a stale file left in the
    # folder by an earlier build is never run.
    (dest / "index.json").write_text(json.dumps({"presets": staged}, indent=2))
    return staged


def build(label: str, module: str, rnd: int, only: list[str] | None) -> dict:
    ensure_imported()
    commit = git_commit()
    staged = stage_bench_presets()
    (GAME / "verify" / "build_info.json").write_text(json.dumps(
        {"commit": commit, "built_at": dt.datetime.now(dt.timezone.utc).isoformat(), "label": label}))
    out = evidence_dir(module, rnd, "build") if module != "remote" else (ROOT / ".local" / "remote-build")
    out.mkdir(parents=True, exist_ok=True)
    rep = {"label": label, "commit": commit, "bench_presets": staged, "exports": []}
    for name, rel in PRESETS.items():
        if only and name not in only:
            continue
        dest = ROOT / "builds" / label / rel
        r = export_one(GAME, name, dest)
        pack = dest if name == "macOS" else dest.with_suffix(".pck")
        r["size_bytes"] = size_of(dest) + (0 if name == "macOS" else max(size_of(pack), 0))
        try:
            chk = check_pack(pack, GAME, ROOT / "ASSETS.md")
            r["packed_files"] = len(chk["files"])
            r["unlisted"] = chk["unlisted"]
            write_json(out / f"packed-{rel.split('/')[0]}.json", chk)
        except Exception as e:  # noqa: BLE001
            r["pack_error"] = str(e)
            r["ok"] = False
        if name == "macOS":
            r["within_4gb"] = 0 <= r["size_bytes"] <= 4 * 1024 ** 3
        r["ok"] = r["ok"] and not r.get("unlisted")
        rep["exports"].append(r)
    rep["pass"] = all(e["ok"] for e in rep["exports"])
    write_json(out / "build.json", rep)
    return rep


# --- setup check ---------------------------------------------------------------

def setup_check() -> int:
    missing = []
    try:
        v = subprocess.check_output([GODOT, "--headless", "--version"], text=True, env=godot_env()).strip()
        if not v.startswith("4.7.2.stable"):
            missing.append(f"Godot 4.7.2 (found {v})")
    except Exception:
        missing.append("Godot 4.7.2")
    tpl = ROOT / ".local" / "data" / "godot" / "export_templates" / GODOT_VERSION / "version.txt"
    if not tpl.exists():
        missing.append("export templates 4.7.2 (see SETUP.md, Export templates)")
    for tool in ("git", "curl", "unzip"):
        if not shutil.which(tool):
            missing.append(tool)
    try:
        import PIL  # noqa: F401
    except ImportError:
        missing.append("Python Pillow")
    print("all present" if not missing else "missing:\n  " + "\n  ".join(missing))
    return 1 if missing else 0


# --- main ----------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("preset")
    r.add_argument("--module", default=None)
    r.add_argument("--round", type=int, default=1)
    r.add_argument("--normal", action="store_true", help="normal launch timing instead of test mode")
    r.add_argument("--out")
    r.add_argument("--baseline")
    r.add_argument("--engine-arg", action="append", default=[], help="extra engine flag, e.g. --engine-arg=--rendering-method --engine-arg=mobile")
    r.add_argument("--tag", default="", help="suffix for the evidence folder name")
    pr = sub.add_parser("prove")
    pr.add_argument("which", choices=list(PROOFS) + ["all"])
    pr.add_argument("--round", type=int, default=1)
    b = sub.add_parser("build")
    b.add_argument("--label", default="latest")
    b.add_argument("--module", default="verify")
    b.add_argument("--round", type=int, default=1)
    b.add_argument("--only", action="append")
    w = sub.add_parser("window")
    w.add_argument("--wm", default="niri", choices=list(WM_WRAP))
    w.add_argument("--round", type=int, default=1)
    rm = sub.add_parser("remote", help="the remote loop: check, send, bench, play, fetch")
    rm.add_argument("target")
    rm.add_argument("verb", choices=["check", "send", "bench", "play", "fetch"])
    rm.add_argument("--now", action="store_true", help="for a person only: skip the five-minute guard")
    sub.add_parser("setup-check")
    a = ap.parse_args()

    if a.cmd == "run":
        p = Path(a.preset)
        d = json.loads(p.read_text())
        module = a.module or d.get("module", "verify")
        name = d.get("id", p.stem) + ("-normal" if a.normal else "") + (f"-{a.tag}" if a.tag else "")
        out = Path(a.out) if a.out else evidence_dir(module, a.round, name)
        log = run_preset(p, out, test_mode=not a.normal, baseline=Path(a.baseline) if a.baseline else None,
                         engine_args=a.engine_arg)
        o = log["orchestrator"]
        ft = log.get("frame_time", {})
        print(json.dumps({"out": str(out.relative_to(ROOT)), "errors": o["error_count"],
                          "frame_ms": ft.get("frame_ms"), "gpu_ms": ft.get("gpu_ms"),
                          "budget": ft.get("budget"), "image": {k: v for k, v in log.get("image", {}).items() if k != "reference_distance"}},
                          indent=1, default=_json_default))
        return 1 if o["error_count"] else 0
    if a.cmd == "prove":
        names = list(PROOFS) if a.which == "all" else [a.which]
        allok = True
        for n in names:
            res = PROOFS[n](a.round)
            res["commit"] = git_commit()
            res["date"] = dt.datetime.now().isoformat(timespec="seconds")
            write_json(evidence_dir("verify", a.round, "proofs") / f"{n}.json", res)
            print(f"{n}: {'PASS' if res['pass'] else 'FAIL'}")
            allok = allok and res["pass"]
        return 0 if allok else 1
    if a.cmd == "build":
        rep = build(a.label, a.module, a.round, a.only)
        for e in rep["exports"]:
            print(f'{e["preset"]}: {"ok" if e["ok"] else "FAIL"} size={e.get("size_bytes")} files={e.get("packed_files")} unlisted={e.get("unlisted")} errors={e["errors"][:3]}')
        return 0 if rep["pass"] else 1
    if a.cmd == "window":
        res = window_test(a.wm, a.round)
        res["commit"] = git_commit()
        write_json(evidence_dir("verify", a.round, f"window-{a.wm}") / "window-test.json", res)
        print(json.dumps(res, indent=1, default=_json_default))
        return 0 if res["pass"] else 1
    if a.cmd == "remote":
        import remote
        try:
            tgt = remote.load_target(a.target)
            build_fn = lambda label, preset: build(label, "remote", 0, [preset])
            if a.verb == "check":
                res = remote.check(tgt)
            elif a.verb == "send":
                res = remote.send(tgt, build_fn, f"remote-{tgt['name']}")
            elif a.verb == "bench":
                res = remote.bench(tgt, build_fn, now=a.now)
            elif a.verb == "play":
                res = remote.play(tgt, build_fn, now=a.now)
            else:
                res = {"fetched": remote.fetch(tgt)}
        except remote.RemoteError as e:
            print(f"remote {a.target} {a.verb}: {e}")
            return 1
        except Exception as e:  # noqa: BLE001 - one plain line, never a traceback
            print(f"remote {a.target} {a.verb}: failed: {e}")
            return 1
        print(json.dumps(res, indent=1, default=_json_default))
        return 0
    if a.cmd == "setup-check":
        return setup_check()
    return 2


if __name__ == "__main__":
    sys.exit(main())
