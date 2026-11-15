# Build notes

One entry per round: what was tried, what failed, why. Read this first when resuming.

## 2026-11-15 — start (stage 1)

- Folder was empty apart from `BUILD-BRIEF.md`; the dotfiles visible inside the sandbox are its placeholders (character devices), not real files, so they are excluded locally in `.git/info/exclude`.
- Machine: MacBook Pro 16" M1 Pro, Fedora Asahi 44, live session GNOME (Wayland). The sandbox has no `/dev/dri`; everything that draws runs outside it.
- Godot 4.7.2 (Fedora build `4.7.2.stable.fedora.ed1daf0bf`). Official export templates 4.7.2-stable downloaded (SHA-512 checked) into `.local/data/godot/export_templates/4.7.2.stable`.
- Nick authorised one edit to `BUILD-BRIEF.md` (2026-11-15): the AAA look-and-feel goal, added as a paragraph under Goal. The same goal is quoted in `ARCHITECTURE.md` → Goal. No other change to the brief.

## verify, round 1 (building)

- Memory: the first reading came before the viewport had grown to the preset's size, and before any 3D camera existed (3D buffers are made lazily), so a 64 MiB texture read as 128 MiB. Fixed with a base scene loaded before the baseline. The engine also keeps a ~67 MB upload staging buffer after the first big upload. Three load/unload cycles proved it flat, not a leak, so the 5% return is judged on a warm cycle, with first-load and cycle growth reported too (ARCHITECTURE.md, Measured events).
- `/proc/self/statm` reads as empty through `get_as_text()` (proc files report length 0); `get_line()` works.
- `OS.get_processor_name()` raises an engine error on Asahi (no CPU model); the log records the core count instead.
- `ViewportTexture.get_size()` under canvas_items stretch reports window²/base size, not drawn pixels; the fill check uses a real frame grab instead.
- Honeykrisp refuses vsync off. Benchmarks ask for off, then mailbox; the log records the mode in use. PNG saves on the main thread (~120 ms) are excluded from the frame that follows, and counted.
- Hang at exit: Godot issue #123059 (Wayland shutdown race), proved with eu-stack. Not the libdecor GTK plugin (that was a guess from glycin threads in a /proc dump; cairo still hung 1 in 6). Workaround in decision windowing.
- Benchmarks: in a GNOME window, compositor pacing put waves of 25–35 ms frames into an empty scene. The harness now makes pinned-resolution presets fullscreen (decision verification-rendering).
- Even fullscreen, 5–8% of empty-scene frames take 16.7–23 ms. These are not clean multiples of the 8.33 ms refresh, and render CPU and GPU stay under 2 ms. The p95 sits around 15–17 ms, on the budget's edge. **For `core`:** find where that time goes (frame_pre_draw→post_draw against the swapchain wait; `Engine.max_fps` at the refresh rate; swapchain image count) before claiming the empty-scene frame budget.
- Release builds buffer stdout. Self-termination dropped the last printed lines until `application/run/flush_stdout_on_print` was turned on.
