#!/usr/bin/env python3
"""Run a movement preset's simulation headless, as fast as the processor goes.

  python3 tools/dev_headless.py <preset.json> [--ticks N] [--out result.json]

For working on the body only: nothing is drawn, so nothing here is evidence.
Evidence comes from `tools/verify.py run`, on the real graphics chip.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("preset")
    ap.add_argument("--ticks", type=int)
    ap.add_argument("--out")
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--trace", type=int, default=0, help="print each body every N ticks")
    a = ap.parse_args()
    preset = Path(a.preset).resolve()
    out = Path(a.out).resolve() if a.out else verify.ROOT / ".local" / "dev" / (preset.stem + ".result.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    verify.ensure_imported()
    cmd = [verify.GODOT, "--headless", "--fixed-fps", "60", "--path", str(verify.GAME),
           "res://movement/fixtures/headless_runner.tscn", "--",
           "--dev-preset", str(preset), "--dev-out", str(out), "--repo-root", str(verify.ROOT)]
    if a.ticks:
        cmd += ["--dev-ticks", str(a.ticks)]
    if a.trace:
        cmd += ["--dev-trace", str(a.trace)]
    try:
        proc = subprocess.run(cmd, env=verify.godot_env(), capture_output=True, text=True, timeout=a.timeout)
    except subprocess.TimeoutExpired as e:
        print("timed out\n" + (e.stdout or "")[-3000:] if isinstance(e.stdout, str) else "timed out")
        return 1
    text = proc.stdout + proc.stderr
    scan = verify.scan_output(text)
    for line in scan["errors"][:20]:
        print("ENGINE", line)
    for line in text.splitlines():
        if line.startswith("TRACE"):
            print(line)
    if out.exists():
        print(out.relative_to(verify.ROOT))
    else:
        print(text[-3000:])
    return 1 if scan["errors"] or not out.exists() else 0


if __name__ == "__main__":
    sys.exit(main())
