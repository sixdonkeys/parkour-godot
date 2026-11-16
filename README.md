# Ridgeline

An original 3D parkour racing game for a father and son, built in Godot 4.7.2: timed runs through four invented courses dressed as real places (the Sonoran Desert around Tucson, the Black Hills, Chicago rooftops, New York rooftops).

The build is driven by `BUILD-BRIEF.md`. Current state and next steps: `HANDOFF.md`. The design is in `ARCHITECTURE.md`, and progress is in `docs/STATUS.json`. Status: stage 1. The verification tool, the core and runner movement exist; there is nothing to play yet.

## Open the project

1. Install what `SETUP.md` lists, and run its check.
2. Open `game/project.godot` in Godot 4.7.2 (macOS: `Godot.app`; Linux: `godot game/project.godot`).

## Run the game

From the project folder: `godot --path game`. Until `core` and the menu exist, this opens an empty window.

## Run the verification tool

All commands are run from the project folder. On the Fedora laptop, anything that draws runs outside the Claude Code sandbox (see `SETUP.md`).

| What | Command |
|---|---|
| Run one preset | `python3 tools/verify.py run docs/presets/<preset>.json --round <n>` |
| Prove the instruments on their known-answer fixtures | `python3 tools/verify.py prove all` (or one of `image`, `frametime`, `memory`, `sound`, `build`, `window`, `input-motion`, `fuzz`, `jump`) |
| Try a movement preset's simulation with no window, in seconds (for working on the body; not evidence) | `python3 tools/dev_headless.py docs/presets/movement-fuzz.json` |
| Rewrite the metrics course and the fuzz fixtures' courses | `python3 tools/gen/metrics_course.py` |
| Window test under a tiling window manager (nested) | `python3 tools/verify.py window --wm niri` (or `umbriel`) |
| Export all four builds and check what's packed | `python3 tools/verify.py build --label <name>` |
| Run on a test machine (the Neo) | `python3 tools/verify.py remote neo check` — also `send`, `bench`, `play`, `fetch` |
| Fetch third-party assets (checked against `tools/assets.lock.json`) | `python3 tools/fetch_assets.py` |
| Check this machine's tools | `python3 tools/verify.py setup-check` |

Results land in `docs/evidence/<module>/round-<n>/<preset>/`: `log.json` (errors, adapter, frame times, memory, sound, window steps, and for movement presets the input-to-motion histogram, the fuzz counts, the measured movement numbers and the run's end-state hash), `still.png`, and, git-ignored, `strip/` frames and `audio.wav`.

To move the placeholder body by hand there is no menu entry yet (the camera and the interface come later); the movement presets drive it through the input map: `python3 tools/verify.py run docs/presets/movement-showcase.json`.

Every build carries a **benchmark mode** that runs every bundled benchmark preset and writes the same logs and PNGs:

```
./Ridgeline.arm64 -- --bench <output folder>
```

On macOS, the executable is `Ridgeline.app/Contents/MacOS/Ridgeline`.

## Get a build onto another Mac

1. `python3 tools/verify.py build --label <name>` writes `builds/<name>/macos/Ridgeline.zip` (universal, ad-hoc signed, not notarized).
2. Copy the zip over (AirDrop, a shared folder, `scp`) and unzip it on the Mac.
3. First launch: Control-click `Ridgeline.app` → **Open** → **Open**. If macOS still refuses, run `xattr -dr com.apple.quarantine Ridgeline.app` in Terminal, in the folder that holds the app.
