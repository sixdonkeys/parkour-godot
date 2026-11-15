#!/usr/bin/env python3
"""Window-test driver for Umbriel. Run as Umbriel's startup command:

    umbriel -c tools/wm/umbriel-test.toml -s "python3 tools/wm/drive_umbriel.py <godot command...>"

Starts the game inside that niri, and whenever the game prints
`VERIFY mark <name>` performs the matching Umbriel action, so the window manager,
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

# Umbriel resizes by fractions of the output (as in its own key bindings,
# e.g. "window-modify-primary-extent -0.1"). Nested, a lone window starts at
# the full width (fraction 1.0).
ACTIONS = {
    "column": [["window-modify-primary-extent", "-0.667"]],
    "half": [["window-modify-primary-extent", "+0.167"]],
    "strip": [["window-modify-primary-extent", "+0.5"], ["window-modify-secondary-extent", "-0.667"]],
    "fullscreen": [["window-toggle-fullscreen"]],
    "focus_out": [["window-focus-or-workspace-down"]],
    "focus_in": [["window-focus-or-workspace-up"]],
    "fullscreen_off": [["window-toggle-fullscreen"]],
}


def act(name: str) -> None:
    for a in ACTIONS.get(name, []):
        r = subprocess.run(["umbriel", "msg", *a], capture_output=True, text=True)
        log(f"DRIVER umbriel {name}: {' '.join(a)} -> {r.returncode} {r.stderr.strip()}")


def main() -> int:
    v = subprocess.run(["umbriel", "--version"], capture_output=True, text=True)
    log(f"DRIVER umbriel version: {v.stdout.strip()}")
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
    subprocess.run(["umbriel", "msg", "session-quit", "skip-confirmation"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
