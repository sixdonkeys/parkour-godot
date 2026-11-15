# Decision: verification-rendering

- **Options:**
  1. `--headless`: rejected outright; it swaps in the headless display driver and Dummy audio, so nothing is drawn.
  2. Movie Maker (`--write-movie`): real GPU, deterministic frames, but non-real-time, so its frame times mean nothing.
  3. In-game capture in a normal window on the real GPU: the root viewport is pinned to the preset resolution, frames are read back after `frame_post_draw`, and timing comes from the same run.
  4. External screenshots from the compositor (`gnome-screenshot`, `grim`): depends on the window manager and catches whatever sits on top of the window.
- **Sources:** see `docs/survey/verification-rendering.md` — Godot command line tutorial (godot-docs `command_line_tutorial.rst`); Creating movies (`creating_movies.rst`); class reference 4.7.2 for RenderingServer, Viewport, Window, OS, Logger (github.com/godotengine/godot, tag `4.7.2-stable`, `doc/classes/`); local `vulkaninfo`.
- **Choice:** option 3. The orchestrator `tools/verify.py` starts the editor binary with `--path game` and `-- --preset <file>` in a normal window, outside the sandbox. In test mode the in-game runner (`game/verify/`):
  - Sets the root window's `content_scale_mode` to viewport and `content_scale_size` to the preset's resolution with aspect `keep`. The 3D world then renders at exactly the preset's pixel size, whatever size the window manager gave the window. Both sizes are logged.
  - Waits for `RenderingServer.frame_post_draw`, then saves `get_viewport().get_texture().get_image()` as PNG. A strip is every n-th frame of the same run, so the still and the numbers beside it always come from one run.
  - Logs the adapter (`RenderingServer.get_video_adapter_name/vendor/api_version`, `OS.get_video_adapter_driver_info`) and the rendering method. If the adapter name matches `llvmpipe|lavapipe|softpipe|SwiftShader|Microsoft Basic`, the log marks `software_renderer: true` and its frame numbers count for nothing.
  - Registers an `OS.add_logger` Logger, so every engine error and warning goes into the JSON log. The orchestrator also scans stdout/stderr for `ERROR:` and `SCRIPT ERROR:`. It sets its own exit code from these rather than trusting the engine's, which is 0 even after errors.
  - Reads process memory from `/proc/self/statm` on Linux and `ps -o rss= -p <pid>` on macOS. Windows has a `tasklist` fallback; if none answers, it logs `-1`, never a guess. Video memory is `Performance.RENDER_VIDEO_MEM_USED`.
  - Movie Maker (option 2) is kept only to check determinism where no timing is read.
- **Reason:** only option 3 gives a picture and its frame-time numbers from the same run on the real chip. Pinning the root viewport's size answers "capture at a preset's resolution when the window manager decides the window's size" without the game ever asking for a window size. The Logger closes the exit-0 gap.
- **Licence:** Godot engine, MIT (Expat). Python 3 (PSF licence), numpy (BSD-3-Clause) and Pillow (MIT-CMU) are used by the orchestrator only and never shipped.
