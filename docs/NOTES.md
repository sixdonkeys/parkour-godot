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
- Round 2 fixes: the remote loop won't start while Low Power Mode is on (the son switched it on mid-wait); it wakes the Neo's display at run start (`caffeinate -u -t 2`); exports exclude `assets/polyhaven/*` until a level uses them; logs carry the host graphics driver (vulkaninfo: Honeykrisp, Mesa 26.2.6) and the rendering device; new showcase `verify-showcase` has real content, and its test-mode/normal pair matches exactly (SSIM 1.0, pixel std 26.8), so the pair now proves something.
- **First valid Neo run** (`docs/neo/2026-11-15-b0545da5a3c6/`): the four light presets are within budget (p95 6.8–9.9 ms); the stress path is at 43.1 ms; zero errors. The honesty rule had first voided it over a Finder sample taken 0.5 s before the game window existed; samples before the game first reaches the front no longer count (decision remote-test). Calibration: Neo ÷ laptop GPU is 1.51–2.24×, so the proxy factor is now 2.3 (CALIBRATION.md).
- The leak flag is proved both ways: the critic's 2048² fixture over 6 cycles stays quiet (unload series 406 → 424 then flat, last step under 1%); `verify-memory-leak` fires (411 → 435 → 456 → 478 MB).
- **Nick's decision, 2026-11-15:** depart from item 3's "one agent builds" for the hardest work. Two Fable agents work in parallel, each in its own git worktree: (1) the desert look-slice inside the Neo frame budget; (6) the player body, movement numbers, input latency, fuzz, and the run and input harness. Their briefs are in `.local/fable-briefs.md` (#1, #6). The main builder merges their branches and keeps the critic loop. Frame-time measurements are serialized with a GPU lock (`.local/gpu.lock`), so concurrent runs don't skew each other.
- **Nick's decision, 2026-11-15:** keep the higher-quality graphics for machines that can run them. The game will ship more than one quality profile (the brief said one, `neo`), and the `interface` settings screen offers a picker; `neo` stays the default on the Neo. Every Neo speed cut is made as a profile setting, never by removing detail from a level. The desert-budget agent was told.

## movement: player body, movement numbers, input latency, fuzz (Fable agent, branch `fable/player-body`, 2026-11-15)

Built in a worktree, on its own branch, to brief #6 in `.local/fable-briefs.md`. Self-checked only: no critic round, `docs/STATUS.json` untouched. Evidence is under `docs/evidence/movement/round-1/`; `summary.json` there collects every number from the logs.

What exists now:
- Records `player-body`, `movement-numbers`, `input-latency`, with surveys. `replay` is still undecided (brief #7).
- `game/movement/`: `PlayerBody` (kinematic, on the adopted `stairs-character`), `MovementTuning`, `MovementActions`, the input sources `RandomInput`, `ScriptInput`, `ManualInput`, `LookFeeder`, `MovingSurface`; fixtures and the two instruments (`instruments/fuzz_probe.gd`, `instruments/metrics_probe.gd`). `game/core/world_clock.gd` is new.
- In `verify`: an input harness that plays an input script through the input map by physics tick (`game/verify/input_harness.gd`), the input-to-motion instrument (`game/verify/input_latency.gd`) and its fixture; `tools/verify.py prove input-motion|fuzz|jump`.
- `docs/fixtures/metrics-course.json` and three small fuzz courses, written by `tools/gen/metrics_course.py`.
- `tools/dev_headless.py`: a preset's simulation with no window, in seconds. Not evidence; it is how ten-minute fuzz runs were tried over many seeds while building.

What was tried, what failed, why:
- **A launch came out at 40% of its height.** The jump proof caught it on its first run (apex 0.50 m for an expected 1.25 m). Mechanism: `launch()` left the body in the "rising from a jump" state with jump not held, so the short-hop gravity (×2.5) applied. Now only the player's own jump is cut short.
- **A body put down by `teleport()` hovered.** The engine's `is_on_floor()` only changes inside `move_and_slide()`, so after a teleport it still said "on floor" from the last place, no gravity was applied, and `state` stayed `AIRBORNE` for ever. The movement instrument showed it as every step and slope lane failing. `teleport()` and `launch()` now mark the body off the floor for the next tick.
- **The body stopped dead at stairs it could climb.** Traced, not guessed: when the riser is first touched at the end of a tick's motion, `stairs-character` tests the landing with a sliver of forward motion; the cylinder is set down overlapping the tread by a millimeter and meets its edge, whose normal fails the floor-angle check. Jolt also rounds a box's edges by `Shape3D.margin` (0.04 m by default; the class reference says so), which widens the sliver case to several centimeters. Two fixes: the forward test reaches at least 0.1 m (a change to the adopted script, `docs/upstream/stairs-character.md`), and boxes that bodies run on use a margin of 0.002 m. **For `kit` and the levels:** set that margin on every box collider, or ledges can't be landed on at their edge.
- **Stairs fired `left_ground` and `landed`.** Right after a step-up the engine can miss the floor for one tick. The body now keeps its own ground state through it.
- **The first fuzz input never ran fast.** Its pushes alternate direction (that is what makes "stuck" mean stuck), so the body never got past 7.7 m/s. It now also sprints for up to six seconds and lets go when it has made no headway for half a second, as a player would; top speed and beyond are reached.
- **The fuzz run found a body inside the tower.** 2 seeds of 8. Mechanism: the fixture put a body at a fixed spawn point inside the lift when the lift was up; being pushed out of the lift pushed it into the tower's wall. A fixture fault, fixed (spawn points on a moving surface ride with it), but the mechanism is real: **a moving surface must never close a gap narrower than a body against fixed geometry.** Rule for `kit`.
- **`tools/verify.py run --engine-arg=--headless` hangs.** The runner waits on `frame_post_draw`, which never comes without a renderer. Hence the separate headless runner.
- **The input-to-motion proof's first bound was wrong twice.** "Delay plus two frames at the 95th percentile" failed on one reading in a hundred (a long frame), and 100 ms is exactly 12 frames at 120 Hz, so the answer flipped between 13 and 14 frames. The fixture now uses 104 ms and 37 ms and the proof states the exact answer, (ceil(delay / P) + 1) × P; the instrument reads it to within 0.3 ms.
- **Frame strips disturb frame times** by more than the one frame the instrument leaves out: the same run read GPU p95 6.1 to 6.3 ms without a strip and 7.5 ms with one every 30 frames. So `movement-run-budget` (no strip) is the budget evidence and `movement-showcase` (strip) is not. `game/verify/frame_stats.gd` was not changed; that is the main builder's to decide.
- **The frame budget with a body passes, but not every time on this machine.** `movement-run-budget` (the showcase's run, no strip, no grid) was run five times: four passed (GPU p95 × 2.3 = 14.3 to 16.5 ms against 16.7; p99 × 2.3 = 16.0 to 20.7 against 22) and the first failed (18.7 and 22.4 ms; wall p95 16.8 ms). The simulation was identical each time (same end-state hash), so the spread is the machine's: GPU p95 for the same frames ranged from 6.2 to 8.1 ms. The failed run was made while two of this agent's verification jobs were queued against each other and the load average stood at 2 to 3.5; that the load caused it is **not shown**, only that nothing in the game differed. The failed log is kept as `movement-run-budget-first-pass`. The body itself costs little: its tick's scripts take 0.2 to 0.3 ms (one body, in a window), and a scene with a standing body read 0.08 ms more GPU at p50 than the same scene with none.
- **The course's one-meter grid costs about 0.25 ms of GPU** at the Neo's resolution, whether mapped triplanar or by texture coordinates: its lines are edges for SMAA. The budget run turns it off. The neo profile's fixed costs leave about 1 ms of GPU under the proxy limit on this machine, which is thin (already noted under core).

The evidence was taken at commit `a8290d1`. One code commit follows it, `0a24599`, which changes spelling only (comments, the key `meters` in the instrument's report, one policy string, and the `units`, `purpose` and one piece name in the course files). Checked headless after it: the same end-state hashes, the same movement numbers, the same counts on the fuzz fixtures.

**The Neo (valid run, `docs/neo/2026-11-15-0a24599c3093/`, `CALIBRATION.md` beside it).** The first two tries were refused (the Neo did not answer once, then had been touched within five minutes); the third ran, never with `--now`.
- Frame budget with a body: `movement-run-budget` 11.2 ms at p95 and 11.4 ms at p99 (budget 16.7 and 22). Met.
- Input to motion: key 32.1 ms, gamepad 32.5 ms at p95, judged from the moment the event is handed to the engine (budget 50). Met. From `_input` it is 16.9 and 17.0 ms.
- Fuzz: 600 s, 72,007 ticks, three zeros.
- The scripted run ended in the same state as on the laptop, bit for bit (same hash). The ten-minute fuzz run did not: same event counts, but the highest point reached differs in the eighth digit. Worth knowing for `replay`.
- The laptop's frame-limiter run does not predict the Neo's input to motion (22.8 against 32.1 ms); two 60 Hz frames is the bound to use.
- `docs/decisions/neo-proxy.md` was not changed: the ratio seen (1.87× and 2.06×) is inside the range the factor of 2.3 already covers.

Checked without a window (`tools/dev_headless.py`, so not evidence): ten-minute fuzz runs over 29 more seeds, three of them with eight bodies, all three zeros after the lift fix; a ghost runs straight through a standing live body, and a live body is stopped by it.

For the main builder, when merging:
- Shared files changed, all additively: `game/verify/verify.gd` (two preloads, `resolve_path()`, one block after "Sound", one line marking the still as saved, one block at the end of the frame loop, one block before `fixture_result` is read, one block restoring v-sync); `tools/verify.py` (a `real_time` check at the top of `run_preset`, the movement proofs registered after `PROOFS`, the proof's evidence module, staging of course files and input scripts in `stage_bench_presets`, extra lines in the `run` summary); `docs/presets/README.md`, `docs/fixtures/README.md`, `README.md`, `ARCHITECTURE.md` (API, three measured events, three table rows), `ASSETS.md` (one entry at the end). New files only otherwise.
- `python3 tools/verify.py prove all` now also runs the three movement proofs (about ten minutes more).
- Benchmark presets added: `movement-run-budget`, `movement-input-motion-key`, `movement-input-motion-pad`, `movement-fuzz`. They add about 17 minutes to a bench, ten of them the fuzz run.
- The export packs `thirdparty/stairs-character/stairs_character.gd` but not its `LICENSE` file (the engine exports resources only). The MIT notice has to reach players some other way: the credits screen (`interface`), or the file added to the export filter.
- Course files and input scripts that a benchmark preset points at are staged into `game/verify/bench_presets/paths/` beside the camera paths, because the export filter already covers that folder; `game/export_presets.cfg` was not touched.

Stale, kept because nothing is deleted: `docs/evidence/movement/round-1/proofs/movement-latency-delay-100/` and `movement-latency-delay-40/` are logs from the input-to-motion proof's first version (fixtures that no longer exist under those names, commits `93a47f8` and before). The proof that counts is `proofs/input-motion.json` with `movement-latency-delay-104/` and `-37/`. They can go if Nick says so.

Left for later:
- `replay` (brief #7): the record, `RecordingInput`, the 20-replay hash check. `ScriptInput` and the input harness are not the recorded-run format.
- The harness camera in `game/movement/fixtures/` is for strips only. The real rig (module `camera`) should smooth the 0.35 m step-up, which the body takes in one tick.
- Whether live players should collide with each other (`PlayerBody.collide_with_players`, on by default) is a design call nobody has made.
- `docs/metrics.json` is written when `traversal` closes; the measured numbers so far are in `docs/evidence/movement/round-1/movement-metrics/log.json`.
