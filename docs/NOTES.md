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

## remote loop (verify reopened, 2026-11-15)

- Nick asked for remote testing on the Neo and is setting it up now. Built `tools/verify.py remote` (decision remote-test).
- Proved: a full `bench` against `docs/targets/local-folder.json` (export → copy → install → run → honesty samples → fetch into `docs/local-folder/2026-11-15-62b2ca8778fe/`); `check` against an unresolvable host and a timing-out host, each one plain line in under 9 s.
- Nick suggested a GitHub Actions runner; declined for now (it installs a service, needs pushes, and struggles to reach the GUI session). Reasons are in the decision record.
- Open until the Neo answers: `open` over SSH on its macOS, the display-power probe on Apple silicon, and `lsappinfo` from SSH.
- In this run's bench, every preset missed the frame budget: the build now applies the neo profile, and FSR2 costs ~7.7 ms of GPU per frame here even on an empty scene (empty scene: bilinear 0.9 ms, bilinear+TAA 4.1 ms, FSR1 4.9 ms, FSR2 8.6 ms). On the Neo the profile picks MetalFX instead. Its cost there is unmeasured, and a single forum report puts it near 10 ms on an M1 Pro. **Next in core:** decide the neo profile's upscaler from these numbers, and from the Neo's own once it answers.

## core, round 1 (building)

- Records: renderer (Forward+; Mobile measured 24% cheaper at matched features, kept as the measured fallback), quality-profiles, multiplayer-readiness.
- Upscaler/AA costs on the empty scene (GPU p50): bilinear 0.88 ms, +TAA 4.05, FSR1+TAA 4.92, FSR2 8.64, FSR1+SMAA 4.31, FSR1+FXAA 3.93, native+SMAA 2.59. `neo` now uses SMAA with non-temporal upscalers, MetalFX temporal first on the Neo. Empty-scene GPU p95 is 6.07–6.21 ms against the 6.68 ms proxy limit: a thin margin, and look-slice will press on it.
- Godot's `JSON.parse_string` raises an engine error on bad input; Save uses `JSON.parse()`.
- The memory leak flag first counted the heap settling over early cycles as growth. It now compares the last two unloads only (ARCHITECTURE.md, Measured events).

## look-slice (started 2026-11-15) — where it stands

- Records done: renderer, quality-profiles, asset-pipeline, lighting, landforms (all five the brief requires before look-slice).
- Terrain source: USGS tile in `tools/cache/usgs/` (git-ignored; address and checksum in ASSETS.md). Python deps for the generator: `.local/venv` with `tools/requirements.txt` (tifffile, imagecodecs pinned to versions over two weeks old).
- Plan:
  1. `tools/gen/terrain.py`: crop the Sabino window, compress (h ×0.1, v ×0.18), resample to 1 m, add seeded slope-weighted detail, bake sky occlusion; write `game/look_slice/generated/` heights (raw float32) + AO PNG + backdrop heights.
  2. `tools/gen/build_terrain.gd`: run headless; chunk meshes (64 m, LODs) + HeightMapShape3D.
  3. CC0 materials and plants (Poly Haven / ambientCG), scatter rules, lighting per the record.
  4. Presets: wide, route, closeup × midday and low sun, plus a benchmark path; critic round (one, scored as a look module).
- Reference photos: a background agent was gathering `reference/`; check whether it finished and committed nothing (the builder commits).

## reference set (gathered 2026-11-15 by a subagent)

- 71 files: 61 place photos plus 10 athletes; all from Wikimedia Commons; licences PD, CC0, CC BY and CC BY-SA only; sha256 in the ledger, re-hashed by the agent.
- Short: `mountain/closeup/lowsun` (1). Searched: Commons categories Custer State Park, Black Elk Wilderness, Needles Highway, Black Elk Peak, Sylvan Lake, Mount Rushmore, Black Hills National Forest, Wind Cave, Black Hills, Granite in South Dakota, Ponderosa pine in South Dakota (06–08 h and 17–21 h); text searches for Needles Eye, Harney Peak granite, ponderosa bark Black Hills, Sylvan Lake sunset, Needles Highway sunset, Black Hills golden hour, Custer State Park morning light. The candidates were foggy, in caves, shaded, over-processed or soft.
- Rejected: the 2024 Javelina Rocks evening series (HDR-looking), a hazy Manhattan water-tower shot, an over-saturated Rushmore ridge, a Needles Eye shot the author says was brightened, overcast New York rooftops, a watermarked parkour jump, a motion-blurred wall climb, black-and-white images.

## verify, round 2 (building)

- Critic round 1: gate not passed (docs/critic/verify-round-1.md). Blocker 1: exports didn't use neo.tres. Mechanism, from the pack itself: the exported binary `neo.res` kept every property name but no string or array values, so `upscalers` fell back to the script default (FSR2). Fixed by `editor/export/convert_text_resources_to_binary=false`. A rebuilt Linux arm64 bench now reports upscalers [metalfx_temporal, fsr, bilinear], chosen fsr, and the three light presets pass (GPU p95 5.6–6.2 ms).
- Nick decided (2026-11-15) the memory 5% is measured from after one earlier load and unload (warm cycle); recorded in ARCHITECTURE.md, Measured events. He also asked for the Neo's machine name and the tailnet ID to be removed from the repo, including from history (rewritten before the first push).
- First Neo bench (2026-11-15, commit f83c521, `docs/neo/2026-11-15-f83c5217a26d/`): **void**. Other apps came to the front (Safari, App Store, System Settings, loginwindow) and one frame took 11.25 s. It counts for nothing; what it showed, as leads only:
  - Metal and MetalFX temporal work, the display is 60 Hz, vsync off is honoured, and there were zero engine errors in all four presets.
  - `viewport_get_measured_render_time_gpu` returns 0 on Metal, so on the Neo the GPU-time instrument is empty and wall-clock frame time is the measure.
  - Empty-scene frame p95 was 6–10 ms. The stress path was about 43 ms against 25.6 ms GPU here, which suggests the proxy factor nearer 1.7 than 2.5. To be settled by an honest run and `CALIBRATION.md`.
  - The window reported 1280×800 although fullscreen was requested; rendering still went at the pinned 2408×1506. The macOS screen size is reported as 2816×1762 at scale 2: the display's "looks like" setting.
