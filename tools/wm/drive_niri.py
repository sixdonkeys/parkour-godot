#!/usr/bin/env python3
"""Window-test driver for niri. Run as niri's startup command:

    niri -c tools/wm/niri-test.kdl -- python3 tools/wm/drive_niri.py <godot command...>

Starts the game inside that niri, and whenever the game prints
`VERIFY mark <name>` performs the matching niri action, so the window manager,
not the game, decides the window's size and focus. Ends niri when the game ends.
"""
import os
import subprocess
import sys

_LOG = open(os.environ["VERIFY_DRIVER_LOG"], "a") if os.environ.get("VERIFY_DRIVER_LOG") else None


def log(msg: str) -> None:
    print(msg, flush=True)
    if _LOG:
        _LOG.write(msg + "\n")
        _LOG.flush()

ACTIONS = {
    "column": [["set-column-width", "33.333%"], ["set-window-height", "100%"]],
    "half": [["set-column-width", "50%"], ["set-window-height", "100%"]],
    "strip": [["set-column-width", "100%"], ["set-window-height", "33.333%"]],
    "fullscreen": [["fullscreen-window"]],
    "focus_out": [["focus-workspace-down"]],
    "focus_in": [["focus-workspace-up"]],
    "fullscreen_off": [["fullscreen-window"]],
}


def act(name: str) -> None:
    for a in ACTIONS.get(name, []):
        r = subprocess.run(["niri", "msg", "action", *a], capture_output=True, text=True)
        log(f"DRIVER niri {name}: {' '.join(a)} -> {r.returncode} {r.stderr.strip()}")


def main() -> int:
    v = subprocess.run(["niri", "msg", "version"], capture_output=True, text=True)
    log(f"DRIVER niri version: {v.stdout.strip()}")
    proc = subprocess.Popen(sys.argv[1:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    for line in proc.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        if _LOG:
            _LOG.write(line)
        if line.startswith("VERIFY mark "):
            act(line.split()[2])
    rc = proc.wait()
    log(f"DRIVER game exited {rc}")
    subprocess.run(["niri", "msg", "action", "quit", "--skip-confirmation"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
