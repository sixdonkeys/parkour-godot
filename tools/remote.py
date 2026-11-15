"""The remote loop (decision remote-test): `verify.py remote <target> <verb>`.

Verbs: check, send, bench, play, fetch. A target is docs/targets/<name>.json:

  {"name": "neo", "transport": "ssh", "ssh_host": "neo", "os": "macos",
   "display": [2408, 1506], "folder": "~/RidgelineTest", "build": "macOS",
   "guard_idle_s": 300}

Nothing is installed on the target: tools/remote/agent.sh is piped over SSH on
every call, and it writes only inside the target's folder. `bench` and `play`
never start while the target was used in the last `guard_idle_s` seconds,
unless a person passes --now (the builder never does).
"""
from __future__ import annotations

import datetime as dt
import io
import json
import shutil
import subprocess
import tarfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AGENT = ROOT / "tools" / "remote" / "agent.sh"
TARGETS = ROOT / "docs" / "targets"
SSH_OPTS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8", "-o", "ServerAliveInterval=10"]


class RemoteError(Exception):
    pass


def load_target(name: str) -> dict:
    p = TARGETS / f"{name}.json"
    if not p.exists():
        raise RemoteError(f"no target file {p.relative_to(ROOT)}")
    t = json.loads(p.read_text())
    t.setdefault("transport", "ssh")
    t.setdefault("guard_idle_s", 300)
    if t["transport"] == "local":
        t["folder"] = str((ROOT / t["folder"]).resolve())
    return t


# --- transport -------------------------------------------------------------------

def _ssh(t: dict, remote_cmd: list[str], stdin: bytes | None = None, timeout=120) -> subprocess.CompletedProcess:
    return subprocess.run(["ssh", *SSH_OPTS, t["ssh_host"], "--", *remote_cmd], input=stdin,
                          capture_output=True, timeout=timeout)


def agent(t: dict, *args: str, timeout=120) -> dict:
    """Run the agent on the target with these arguments; return its JSON."""
    script = AGENT.read_bytes()
    if t["transport"] == "local":
        r = subprocess.run(["sh", "-s", "--", *args], input=script, capture_output=True, timeout=timeout)
    else:
        r = _ssh(t, ["sh", "-s", "--", *args], stdin=script, timeout=timeout)
    out = r.stdout.decode(errors="replace").strip().splitlines()
    if r.returncode == 255 and t["transport"] == "ssh":
        err = r.stderr.decode(errors="replace").strip().splitlines()
        raise RemoteError(f"{t['name']}: cannot reach {t['ssh_host']} over SSH ({err[-1] if err else 'no answer'})")
    if not out:
        raise RemoteError(f"{t['name']}: agent gave no answer (exit {r.returncode}): "
                          f"{r.stderr.decode(errors='replace').strip()[:200]}")
    try:
        return json.loads(out[-1])
    except json.JSONDecodeError:
        raise RemoteError(f"{t['name']}: agent answer was not JSON: {out[-1][:200]}")


def put_file(t: dict, local: Path, remote_name: str) -> None:
    folder = t["folder"]
    if t["transport"] == "local":
        Path(folder).mkdir(parents=True, exist_ok=True)
        shutil.copyfile(local, Path(folder) / remote_name)
        return
    with open(local, "rb") as f:
        data = f.read()
    # One string: ssh joins arguments with spaces, so a separate `sh -c` script
    # argument would arrive split (the Neo's first copy failed that way).
    r = _ssh(t, [f"mkdir -p {folder} && cat > {folder}/{remote_name}"], stdin=data, timeout=1800)
    if r.returncode != 0:
        raise RemoteError(f"{t['name']}: copy failed: {r.stderr.decode(errors='replace').strip()[:200]}")


def get_results(t: dict, run_id: str, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    if t["transport"] == "local":
        src = Path(t["folder"]) / "results" / run_id
        shutil.copytree(src, dest, dirs_exist_ok=True)
        return
    r = _ssh(t, ["tar", "-C", f'{t["folder"]}/results/{run_id}', "-cf", "-", "."], timeout=1800)
    if r.returncode != 0:
        raise RemoteError(f"{t['name']}: fetch failed: {r.stderr.decode(errors='replace').strip()[:200]}")
    with tarfile.open(fileobj=io.BytesIO(r.stdout)) as tf:
        tf.extractall(dest, filter="data")


# --- verbs -------------------------------------------------------------------------

def check(t: dict) -> dict:
    """Does the target answer; who is at its screen; awake, unlocked, idle for how long."""
    p = agent(t, "probe", t["folder"])
    p["target"] = t["name"]
    p["free"], p["why_not_free"] = _is_free(t, p)
    return p


def _is_free(t: dict, p: dict) -> tuple[bool, str]:
    if t["guard_idle_s"] and isinstance(p.get("idle_s"), int) and p["idle_s"] < t["guard_idle_s"]:
        return False, f"used {p['idle_s']} s ago (needs {t['guard_idle_s']} s untouched)"
    if t["guard_idle_s"] and p.get("idle_s") is None:
        return False, "idle time unknown"
    if p.get("locked") == "true":
        return False, "screen is locked"
    if p.get("low_power") == "true":
        return False, "Low Power Mode is on (numbers would be throttled)"
    if t["transport"] == "ssh" and p.get("console_user") and p.get("console_user") != p.get("user"):
        return False, f"{p.get('console_user')} is at the screen, not {p.get('user')}"
    return True, ""


def send(t: dict, build_fn, label: str) -> dict:
    """Export the build for this target and copy it over."""
    rep = build_fn(label, t["build"])
    exp = next((e for e in rep["exports"] if e["preset"] == t["build"]), None)
    if not exp or not exp["ok"]:
        raise RemoteError(f"export for {t['build']} failed: {exp}")
    built = ROOT / exp["path"]
    if built.suffix == ".zip":
        put_file(t, built, "incoming.zip")
    else:
        tmp = ROOT / ".local" / f"remote-{t['name']}.tar"
        with tarfile.open(tmp, "w") as tf:
            tf.add(built, arcname=built.name)
            pck = built.with_suffix(".pck")
            if pck.exists():
                tf.add(pck, arcname=pck.name)
        put_file(t, tmp, "incoming.tar")
    res = agent(t, "install", t["folder"], rep["commit"])
    if not res.get("ok"):
        raise RemoteError(f"install failed: {res}")
    return {"commit": rep["commit"], "export": exp, "installed": res}


def bench(t: dict, build_fn, now=False, timeout_s=1800, poll_s=10) -> dict:
    st = check(t)
    if not st["free"] and not now:
        raise RemoteError(f"{t['name']} is not free: {st['why_not_free']}. Nothing was started.")
    sent = send(t, build_fn, f"remote-{t['name']}")
    commit = sent["commit"]
    run_id = dt.datetime.now().strftime("%Y-%m-%d") + "-" + commit[:12]
    started = agent(t, "run", t["folder"], run_id, "bench")
    if not started.get("ok"):
        raise RemoteError(f"could not start the benchmark: {started}")
    t0 = time.monotonic()
    while True:
        time.sleep(poll_s)
        s = agent(t, "status", t["folder"], run_id)
        if not s.get("running"):
            break
        if time.monotonic() - t0 > timeout_s:
            raise RemoteError(f"benchmark still running after {timeout_s} s; fetch it later with `remote {t['name']} fetch`")
    dest = fetch_one(t, run_id)
    return {"run_id": run_id, "commit": commit, "result": str(dest.relative_to(ROOT)),
            "honesty": json.loads((dest / "HONESTY.json").read_text())}


def play(t: dict, build_fn, now=False) -> dict:
    st = check(t)
    if not st["free"] and not now:
        raise RemoteError(f"{t['name']} is not free: {st['why_not_free']}. Nothing was started.")
    sent = send(t, build_fn, f"remote-{t['name']}")
    run_id = "play-" + dt.datetime.now().strftime("%Y-%m-%dT%H%M%S")
    return {"commit": sent["commit"], "started": agent(t, "run", t["folder"], run_id, "play")}


def fetch(t: dict) -> list[str]:
    """Bring back every result folder on the target that isn't here yet."""
    have = {p.name for p in (ROOT / "docs" / t["name"]).glob("*")} if (ROOT / "docs" / t["name"]).exists() else set()
    got = []
    for run_id in agent(t, "list", t["folder"]).get("results", []):
        if run_id.startswith("play-") or run_id in have:
            continue
        if agent(t, "status", t["folder"], run_id).get("running"):
            continue
        got.append(str(fetch_one(t, run_id).relative_to(ROOT)))
    return got


def fetch_one(t: dict, run_id: str) -> Path:
    dest = ROOT / "docs" / t["name"] / run_id
    get_results(t, run_id, dest)
    (dest / "HONESTY.json").write_text(json.dumps(judge_honesty(dest), indent=2) + "\n")
    return dest


def judge_honesty(dest: Path) -> dict:
    """A remote number counts only if the game was really on screen for the
    whole run: display awake, screen unlocked, the game's window in front.
    Power source, low-power mode and refresh rate are recorded beside it."""
    samples = []
    hp = dest / "honesty.jsonl"
    if hp.exists():
        for line in hp.read_text().splitlines():
            try:
                samples.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    reasons = []
    if not samples:
        reasons.append("no honesty samples were taken")
    if any(s.get("locked") == "true" for s in samples):
        reasons.append("screen was locked during the run")
    if any(s.get("display_awake") == "false" for s in samples):
        reasons.append("display was asleep during the run")
    # The game's window only exists a moment after launch, so samples before
    # the game first reaches the front don't count (the Neo's second run had
    # Finder in its launch-moment sample only). Any other app in front after
    # that voids the run.
    first = next((i for i, s in enumerate(samples) if "Ridgeline" in (s.get("front_app") or "")), None)
    during = samples[first:] if first is not None else samples
    fronts = {s.get("front_app") for s in during if s.get("front_app") not in (None, "", "unknown")}
    if fronts and not all("Ridgeline" in f for f in fronts):
        reasons.append(f"another app was in front: {sorted(fronts)}")
    # The game's own log says whether its window kept focus.
    for lp in dest.glob("*/log.json"):
        try:
            log = json.loads(lp.read_text())
        except json.JSONDecodeError:
            continue
        if any(e.get("event") == "app_focus_out" for e in log.get("focus_events", [])):
            reasons.append(f"game lost focus during {lp.parent.name}")
    # Display awake: when no probe can read it, the game's own frames prove it.
    # A sleeping or hidden display stops frame callbacks, which shows as gaps.
    max_gap = 0.0
    refresh = set()
    for lp in dest.glob("*/log.json"):
        try:
            log = json.loads(lp.read_text())
        except json.JSONDecodeError:
            continue
        series = log.get("frame_time", {}).get("series_ms", [])
        if series:
            max_gap = max(max_gap, max(series))
        if log.get("machine", {}).get("refresh_hz"):
            refresh.add(log["machine"]["refresh_hz"])
    display_by_frames = max_gap < 1000.0 if max_gap else None
    if display_by_frames is False:
        reasons.append(f"a frame took {max_gap:.0f} ms: the display slept or the window was hidden")
    unknown = [k for k in ("locked", "front_app")
               if samples and all(s.get(k) in (None, "", "unknown") for s in samples)]
    if all(s.get("display_awake") in (None, "", "unknown") for s in samples) and display_by_frames is None:
        unknown.append("display_awake")
    # Nothing unverifiable may pass: an unread check makes the run void.
    for k in unknown:
        reasons.append(f"could not verify {k}")
    return {
        "void": bool(reasons), "reasons": reasons,
        "unverifiable": unknown,
        "display_awake_from_frames": display_by_frames, "max_frame_ms": max_gap,
        "refresh_hz_game": sorted(refresh),
        "power": sorted({s.get("power") for s in samples if s.get("power")}),
        "low_power": sorted({s.get("low_power") for s in samples if s.get("low_power")}),
        "samples": len(samples),
        "note": "void runs are kept and count for nothing (BUILD-BRIEF item 2)",
    }
