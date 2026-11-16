# Fable briefs: the tough remaining work

Written 2026-11-15. Reading started at commit `edc06ee`; the main builder committed `b0545da` and a second Neo result folder (`docs/neo/2026-11-15-b0545da5a3c6/`, not yet committed) arrived while this was being written, and both are taken into account. Nothing tracked was changed to make this file.

How to read the sources of each statement:
- **[repo]** means the fact is on disk at the path given.
- **[inference]** means it is this file's own arithmetic or reading of the code, from repo numbers.
- **[unverified lead]** means it comes from the briefer's memory, was not checked this session, and must be confirmed at the source before anyone relies on it.

Three things for Nick before any brief goes out:

1. `BUILD-BRIEF.md` item 3 says "Solo. One agent builds". Handing modules to other agents changes that working method. It is your call. The critic rule still holds either way: these agents are builders, they write no score, and the critic is still a fresh agent per round.
2. The brief says a hard problem's record is written "when the first module that depends on it starts, not all of them up front", and only you begin a stage. So only stage 1 work is marked **now**. Where going early would buy lead time (the human character), it says so and leaves it to you.
3. Each of these is a long, high-effort run. Two or three at once will take a real slice of the weekly Max allowance. The sort table gives a cheapest sensible first wave.

## The sort

Ranked hardest first.

| # | Task | Module / stage | Verdict |
|---|---|---|---|
| 1 | Desert slice inside the Neo frame budget | look-slice, stage 1 | **Fable, now** |
| 2 | Desert slice that reads as a photograph | look-slice, stage 1 | **Fable, now for sourcing; integration after #1's first cost table** |
| 3 | Realistic human, mocap moves and contact under the asset policy | character, stage 3 (record due at `interface`, stage 2) | **Fable, later**; search half earlier only if Nick wants the lead time |
| 4 | Traversal: finding and performing the five moves | traversal, stage 1 | **Fable, later**: after #6 and #7 |
| 5 | Course-run solver and the kit instruments | kit, stage 2 | **Fable, later**: after `traversal` closes and `docs/playtest/traversal.md` exists |
| 6 | Player body, movement numbers, input latency, fuzz | movement, stage 1 | **Fable, now** |
| 7 | Replay, determinism and ghosts | movement, stage 1 | **Fable, later**: straight after #6's body passes fuzz (same agent is fine) |
| 8 | The two cities: lidar skyline, building records, block generator | chicago-course, stage 3 | **Fable, later**: at stage 3 start |
| 9 | Trustworthy Neo numbers on Metal | verify (reopened) | **Main builder, now**. Not routine, but it edits the same files verify round 2 is editing. #1 cannot prove anything on the Neo until it is done |

Cheapest sensible first wave: **#1 and #6**, with #9 done by the main builder alongside. Add #2's sourcing half if allowance permits.

Tough, but not briefable yet: the four `-dress` modules (stage 4). `look-slice` gets one critic round and then decides whether the floor, the scope or the target moves (brief item 3). Until that result exists, a dress brief would be guesswork. When it does, #1 and #2 are the templates, and #8 feeds the two city ones.

Not tough enough for a brief (stays with the main builder): see the list near the end.

---

## Shared rules (paste under whichever brief you hand out)

- Read `BUILD-BRIEF.md` in full, then `ARCHITECTURE.md`, `docs/NOTES.md`, `docs/WAITING.md`. The brief is the contract and wins every conflict. Never edit it.
- You are a builder on one piece. You write no score and never set `gate`, `score`, `open_issues`, `closed` or `capped` in `docs/STATUS.json`. Leave `STATUS.json` to the main builder; put your state in `docs/NOTES.md` as a dated entry (what was tried, what failed, why).
- A remote benchmark may be building from the current commit. Do not touch the main working tree or `builds/` until told it has finished. Work on a branch `fable/<task>` in a git worktree, or wait. A fresh worktree lacks the git-ignored inputs: `game/assets/polyhaven/` (remade by `tools/fetch_assets.py`), `tools/cache/usgs/`, `game/*/generated/chunks/` and `*.f32` (remade by `tools/gen/terrain.py` then `tools/gen/build_terrain.gd`), `.local/venv`, and the export templates under `.local/`.
- Commit on your branch; never push (pushes are Nick's). No deleting, no hard reset, no `--no-verify`. File deletion is denied by hook: write new round folders.
- Stack is fixed: Godot 4.7.2, GDScript only for game code, built-in Jolt. Tools outside `game/` are Python 3 with numpy and Pillow.
- Anything that draws runs outside the sandbox (no `/dev/dri` inside it): `python3 tools/verify.py run <preset.json>`. A software renderer's numbers count for nothing.
- Presets live one per file in `docs/presets/`; add new ones, never edit an existing one. Every look or budget preset uses `"profile": "neo"` and `"resolution": [2408, 1506]`. Field list: `docs/presets/README.md`.
- Evidence goes under `docs/evidence/<module>/round-<n>/<preset>/`. A claim is a path plus what it shows. A failed check is reported with its output.
- The Neo is reached only by `python3 tools/verify.py remote neo check|bench|fetch`. Never pass `--now`. A void run counts for nothing and is never tuned against.
- A decision record (`docs/decisions/<problem>.md`) needs Options (two or more), Sources, Choice, Reason and Licence, with the excerpts quoted word for word in `docs/survey/<problem>.md`. The same commit updates the hard-problems table in `ARCHITECTURE.md`.
- Asset policy: shipped assets are public domain, CC0 or credit-only (CC BY). No share-alike, no non-commercial. Third-party code is MIT, Apache-2.0, BSD, zlib or CC0, kept in `game/thirdparty/<project>/` with its licence notice and upstream commit. GPL and AGPL source is off limits even to read. Every asset and dependency gets an `ASSETS.md` entry with the licence statement quoted from the source; `tools/verify.py build` fails an export that packs an unlisted file.
- Nothing from `reference/` ships or becomes a texture: some of those photos are CC BY-SA, and the folder is closed (`reference/APPROVED.md`).
- Determinism: seeded `RandomNumberGenerator` only; all simulation in `_physics_process` at 120 ticks a second; a body reads only its `InputSource`, once per tick.
- Multiplayer must stay possible: no code assumes one player; use `Players` slots (`game/core/players.gd`, `player_slot.gd`). No OS lock-in: project-relative and `user://` paths, input map only, nothing bound to Super.
- Do not fan out subagents. This runs on Nick's weekly allowance.
- Stop when the "done" list is met or you are blocked on something only Nick has. Report what is committed and not pushed.

---

## 1. Desert slice inside the Neo frame budget

**Verdict:** Fable, now. This is the question the whole brief rests on (item 3, `look-slice`).

**Goal.** Get the look-slice's views and its benchmark path to 95% of frames within 16.7 ms and 99% within 22 ms on the Neo, on the `neo` profile at 2408×1506, and leave a per-feature cost table and a frame recipe that every level will inherit.

**Why it's hard.**
- The gap is large. [repo] Route view on the M1 Pro: GPU p50 31.6 ms, 6.4 M primitives, 570 draw calls (`.local/LOOK-SLICE-PROGRESS.md`, `.local/ls-route/log.json`). The proxy limit is GPU p95 6.68 ms (`docs/decisions/neo-proxy.md`).
- The gap is worse than "5×" for content. [repo] An empty scene on the neo profile already costs 4.31 ms here (FSR1 + SMAA; `docs/NOTES.md`, core round 1). [inference] That leaves about 2.4 ms of proxy budget for everything drawn, against about 27 ms spent: nearer 11×.
- The Neo's floor is not settled. [repo] Both Neo runs so far are **void** (`docs/neo/2026-11-15-f83c5217a26d/` and `docs/neo/2026-11-15-b0545da5a3c6/`), but they agree: empty scenes at p50 6.5 to 8.4 ms wall clock with vsync off and MetalFX temporal, a 45,550-primitive showcase at p50 9.6 ms, and the stress path at p50 41.97 and 42.32 ms against 25.65 ms of GPU here (a ratio near 1.65, not 2.5). [inference] If that floor is real, 40 to 50% of the frame is gone before anything is drawn. Leads only until a non-void run exists; settle it first.
- Costs do not add up. [repo] Scatter off saves 12 ms, shadows off 7.6 ms, post off 10 ms. Shadows off also halves the primitives (6.4 M to 3.3 M, `.local/perf-noshadow/log.json`), so much of "scatter" is scatter drawn again into shadow maps.
- The terrain is bound by pixels, not triangles. [repo] The close-up without backdrop draws 0.78 M primitives and still costs 17.1 ms (`.local/ls-close-noback/log.json`); terrain only is 19.6 ms at 0.71 M (`.local/ls-terrain/log.json`). [inference] `game/look_slice/terrain.gdshader` does 13 texture fetches per pixel (12 anisotropic, on 4K maps) and three noise evaluations on every terrain pixel whatever its slope. Mesh detail cuts will not touch that.
- Procedural plants have no detail levels. [inference, from `game/look_slice/scatter.gd`] Meshes committed from `SurfaceTool` get no LODs. Prickly pear is 10 pads × 192 triangles = 1,920 triangles, 5,000 instances, drawn to 160 m; ocotillo about 2,300 triangles, 1,400 instances, to 300 m; saguaro up to about 2,400 triangles, 1,800 instances, to 500 m.
- The Neo cannot tell you where the time goes. [repo] `viewport_get_measured_render_time_gpu` returns 0 on Metal. Every Neo breakdown has to be done by switching one thing off and reading wall clock, and each run needs the Neo idle and the game in front.
- The laptop cannot give honest wall clock. [repo] Honeykrisp refuses vsync off, so frames are paced at 120 Hz; only GPU time is useful here.
- The proxy can mislead exactly where it matters. [repo] The Neo has about 3.3× less memory bandwidth than the M1 Pro (60 against 200 GB/s) while the factor is 2.5 and the void runs hint at about 1.65 on a triangle-heavy scene. Pixel-heavy passes may scale worse than geometry-heavy ones, and the slice is pixel-heavy.
- The Neo uses a different upscaler. [repo] MetalFX temporal on the Neo, FSR1 + SMAA here. A laptop still is not what the Neo shows.
- The easy way to pass is to make it ugly. Every cut needs a before and after still from the same camera.

**Read first.** `.local/LOOK-SLICE-PROGRESS.md`; `.local/ls-*.json` and `.local/perf-*.json` (dev presets) with their `log.json` folders; `game/look_slice/` (all four files); `tools/gen/terrain.py`, `tools/gen/build_terrain.gd`; `game/core/quality_profile.gd`, `game/profiles/neo.tres`; `docs/decisions/` renderer, lighting, quality-profiles, neo-proxy, landforms; both folders under `docs/neo/`; `docs/evidence/core/round-1/core-stress-path*/` and `core-upscaler-*/`.

**Binding constraints.**
- Budget: frame time as above, binding on the Neo's wall clock. Proxy rule until then: wall clock meets the raw budget **and** GPU × 2.5 meets it. Never judged more leniently than the budget.
- Renderer record's own limits: at most 8 M primitives and 2,500 draw calls per frame.
- Memory: at most 4 GB with the slice loaded. [repo] Currently about 1.09 GB loaded on the laptop, 696 MB of it video.
- Every looks-for-speed setting lives in the profile file, not in the scene. Levels are authored at their best; the profile only clamps down. `game/profiles/throwaway-high.tres` must still work.
- The world is generated at build time and fixed. Anything baked (impostors, merged far meshes, a baked terrain colour map) is made by `tools/gen/` from the seed and reproducible.
- No native plugin unless it builds for macOS arm64, Linux arm64 and Linux x86_64. [repo] Terrain3D ships no Linux arm64 library (`docs/decisions/landforms.md`).
- No OS lock-in: the upscaler stays an ordered list with a fallback.
- The slice is a 50 m patch inside the full 1 km of ground with the backdrop. Shrinking the world to pass is not allowed; the sizes are what is being tested.

**Done means.**
- A cost table in `docs/evidence/look-slice/round-1/perf/`: for each of terrain shader, depth prepass, sun shadows (by cascade and distance), each scatter kind, SSAO, fog, glow, upscaler and AA, and render scale, the cost on the laptop (GPU ms) and on the Neo (wall ms), each row naming the preset log it came from.
- A non-void Neo result folder under `docs/neo/<date>-<commit>/` in which the slice's benchmark path passes: p95 ≤ 16.7 ms, p99 ≤ 22 ms. `CALIBRATION.md` beside it, and the factor in `neo-proxy` corrected.
- Primitive and draw-call maxima within the limits, read from the same logs.
- For each cut, a before and after still at the same camera with its SSIM, so the look cost is visible.
- If the budget cannot be met without dropping below what #2 needs: the measured floor, the options with their numbers (render scale, Mobile renderer, world size, the floor itself), and the conflict line for `docs/WAITING.md`. That is a valid, complete outcome. Loosening is Nick's call.
- Records updated wherever a choice moved (renderer has a written reopening trigger for Mobile: 12.6 ms against 16.6 ms at matched features).

**Known leads.**
- [repo] The builder's own list: lower render scale; one triplanar fetch set, not three; scatter impostors; shorter shadow distance for scatter; SSAO at half resolution or off; alpha-tested cards instead of dense scans.
- [repo] Fixes already banked: textures imported without mipmaps cost 200 ms (now 19.6 ms via `tools/set_imports.py`); one MultiMesh over 1 km always drew at full detail (now one per 64 m cell: 87 M to 8.7 M primitives).
- Exemplars the brief names, licences to be confirmed before relying on them: the "Abandoned Spaceship" Godot 4 demo (listed MIT); the "Desert Light" Godot 4 demo (no licence found: study only); the Bistro port (CC BY 4.0); Terrain3D (MIT) as a reference for how a terrain shader bounds its fetches.
- [inference, untested] Shadow casting off for small scatter; LODs for the procedural plants; a single baked colour fetch for terrain beyond some distance; fewer or cheaper shadow cascades for scatter than for terrain.

**Out of scope.** The look itself (sky colour, plant modelling, materials' appearance: that is #2). Movement. Changing any budget number, the preset resolution or the profile's name. Tuning against the void run. Building a level from the slice (it ships in no build).

---

## 2. Desert slice that reads as a photograph

**Verdict:** Fable. The asset search can start now. Integration waits for #1's first cost table, so the look is built inside a known budget. If both run together, #1 owns the shader's structure, the profile, shadow and post settings and the scatter cell mechanics; #2 owns sky, sun and exposure values, textures, plant meshes and the scatter rules.

**Goal.** Make the six stills (wide, route distance, close-up, each at midday and low sun) read as the Sonoran Desert against `reference/desert/`, on the `neo` profile, inside #1's recipe.

**Why it's hard.**
- It is far off today. [repo] `.local/ls-three.png` and the ranked list in `.local/LOOK-SLICE-PROGRESS.md`: flat grey-blue sky; saguaros as a dense stand of smooth green tubes; black shrubs; orange striped mountains where the Catalinas are grey-tan with green scrub; uniform ground.
- There is one critic round. `look-slice` is scored once and closed whatever the score; under 7 goes to Nick as a conflict. Self-checking has to be hard before that round.
- The number can be gamed and gates nothing. The histogram distance is "easy to move with colour alone" (brief item 2). The critic's eye is the score.
- The lighting record and the code disagree. [repo] `docs/decisions/lighting.md` says physical light units, physical camera exposure and clamped auto-exposure. `game/project.godot` does not turn physical light units on, `game/look_slice/look_slice.gd` sets `light_energy` 1.8 by hand, and nothing in `game/` sets camera attributes. Either the code follows the record or the record changes with a reason.
- The plants that make the place are the ones nobody has scanned for free. [repo] `scatter.gd` notes no CC0 saguaro, ocotillo or prickly pear on Poly Haven. The two shrubs in use are wrong: `wild_rooibos_bush` is leaves on black because the fetched JPEG has no cut-out, and `shrub_02` is a temperate shrub.
- The close-up references are a saguaro trunk and cholla (`reference/desert/closeup/`). The procedural tubes must hold at trunk distance: pleats, spines, skin.
- Placement is ecology, not noise. [repo] 1,800 saguaros with a quarter of all picks clustered within about 30 m of the centre (`scatter.gd`, `_pick`). Real bajadas are sparse, with palo verde nurse trees, creosote and bursage between.
- The mountains are 1.8× steeper than life after compression (`landforms`), and the cliff texture is projected at a scale that stripes.
- No haze to hide behind: the reference rules exclude fog and heavy editing, so depth has to come from light and detail.
- Cut-out foliage is the classic cost on this class of chip, and low sun means long shadows inside a 150 m, two-cascade shadow budget.

**Read first.** `reference/desert/` (all six folders) and `reference/LEDGER.md`; `.local/ls-three.png`, `.local/ls-close-pair.png`, `.local/ssao-compare.png`; `.local/LOOK-SLICE-PROGRESS.md`; `game/look_slice/`; `docs/decisions/lighting.md`, `landforms.md`, `asset-pipeline.md`; `ASSETS.md`; `tools/fetch_assets.py`, `tools/assets.json`, `tools/assets.lock.json`, `tools/set_imports.py`; #1's cost table once it exists.

**Binding constraints.**
- Asset policy as in the shared rules. Every new file is pinned by address and SHA-256 in `tools/assets.json` and the lock, and listed in `ASSETS.md`. Files of 20 MB or more stay out of git (`asset-pipeline`).
- Source art is kept at the best quality obtained; reduction is per profile.
- A download that needs a new account, a payment or an EULA click is a pause for Nick, not something to do.
- Frame budget and #1's recipe. A still and its frame numbers come from the same run.
- Seeded placement only; same seed, same world on every machine.
- Presets carry `"look": {environment, view, time}` so the histogram distance is logged against the right folder.

**Done means.**
- Six new presets, `look-slice-{wide,route,closeup}-{midday,lowsun}`, each with `still.png` and `log.json` under `docs/evidence/look-slice/round-1/`, zero engine errors, histogram distances logged.
- For each, a side-by-side sheet with a reference photo from the matching folder, scaled and cropped the way the final gate does it (brief item 5).
- A dry run of the final gate's blind question on at least the three midday pairs, by a fresh agent given only the two image paths, with its give-aways listed. This is a self-check; it is not the critic.
- Each of the six ranked look issues in `.local/LOOK-SLICE-PROGRESS.md` either fixed with a before and after still or stated as still open.
- The frame numbers beside each still, inside #1's recipe.
- `ASSETS.md` complete; `tools/verify.py build` passes its packed-file check.
- The aim is a critic score of 8.5 ("reads as real, with nits a professional would list"); 7 is the line below which it becomes Nick's decision.

**Known leads.**
- [repo] Poly Haven and ambientCG (both CC0) are the planned sources (`docs/NOTES.md`, look-slice plan). Twelve Poly Haven assets are already in (`ASSETS.md`).
- [repo] Black shrubs are solved as a diagnosis: not SSAO, not MultiMesh, not vertex colour; it is the texture variant.
- [repo] Latitude and solar position are already in `look_slice.gd` (`set_time_of_day`).
- [unverified lead] Photographs by US federal agencies (National Park Service, Forest Service, Geological Survey) are generally public domain and could be texture sources for cactus skin and bark. Check each file's own statement.
- [unverified lead] Smithsonian Open Access 3D and CC0 or CC BY models on Sketchfab may hold desert plants or rock; Sketchfab downloads need an account.
- The brief's graphics exemplars as in #1.

**Out of scope.** Frame-cost work beyond staying inside the recipe. The desert level itself. Anything under `reference/`. Adding fog or grading to hide detail. The other three environments.

---

## 3. Realistic human, mocap moves and contact

**Verdict:** Fable, later. The `character-sourcing` record is due when `interface` starts (stage 2); `animation-contact` and the build are `character` (stage 3). The search half has the longest lead time in the whole build, because its likely result is a request to Nick, so he may want it run early. His call.

**Goal.** Find and prove a realistic human body, a set of looks a player can choose, and motion-captured traversal moves that may all ship under the asset policy; then fit them to the body so hands meet ledges and feet meet ground on obstacles of varying size, in both views.

**Why it's hard.**
- The brief itself expects the policy to fall short here ("most likely the realistic human and its motion-captured moves", Rules).
- "Free" is not the policy. Many motion libraries use their own terms, or are non-commercial, no-derivatives or share-alike. An export packs the animation data, so "may not redistribute the files" has to be read against that, from the licence text.
- [repo] The named parkour exemplars do not solve it: Gab-ani's animations "appear not to be free to ship"; the GDQuest demo's art is CC BY-NC-SA.
- Parkour-specific capture (vaults, climb-ups, wall runs, rolls) is rare under any free licence.
- Clips come on different skeletons and proportions. Retargeting brings foot sliding and broken contacts.
- A vault captured over one height does not fit another. Kit pieces vary in size by design.
- Every look must work with every move in both views: clothing on the same skeleton, no clipping, and a first-person view that stays steady on a full body.
- Looks belong to the player: saved with the player, worn by that player's ghost, and two bodies in one level can differ. A level must hold 8 bodies inside the frame budget (`multiplayer-readiness`).
- When `character` closes, `camera` and `traversal` are graded again with the real body.

**Read first.** `BUILD-BRIEF.md` items on `character-sourcing` and `animation-contact`, and the Rules on asset policy and looks; `reference/character/` (ten athlete photos; the module is scored against them); `docs/decisions/multiplayer-readiness.md`; `ARCHITECTURE.md` shared data model (Look, Ghost); the traversal module and `docs/metrics.json` once they exist.

**Binding constraints.** Asset policy; credits owed shown on the credits screen; GDScript only; no native plugin unless it covers all three platforms; memory 4 GB; frame budget with 8 bodies; look is per player; module scored as a look module against `reference/character/` and closes at 8.5.

**Done means (search half).**
- `docs/decisions/character-sourcing.md` complete, with each licence statement quoted in `docs/survey/character-sourcing.md`.
- A table: every move the game needs (run, sprint, jump, land, roll, each vault, ledge climb, wall run, slide) against candidate clips, with source address, licence, quoted statement and a ship or no-ship verdict.
- A proof scene under `game/character/fixtures/` where the chosen body plays at least a run, a vault and a climb fitted to it, captured as frame strips by a new preset, with the packed-file check passing.
- For every gap, the exact `docs/WAITING.md` line of the kind "an asset the policy can't supply", with the search shown and the options for Nick.

**Done means (build half, at `character`).** `animation-contact` record; frame strips of every move on the metrics course in both views with hands and feet on the surfaces; the two-body preset with two different looks; a look change that survives a restart.

**Known leads.** All [unverified lead]: confirm every licence at its source.
- MakeHuman and its Blender add-on MPFB: the briefer recalls the generated models being CC0.
- CMU Graphics Lab Motion Capture Database: recalled as free to use, general motion, not parkour.
- Quaternius animation packs: recalled as CC0.
- 100STYLE dataset: recalled as CC BY 4.0, locomotion only.
- Recalled as non-commercial or no-derivatives, so likely excluded: LAFAN1, AMASS, the Bandai Namco Research motion set.
- Mixamo: Adobe's own terms, not a Creative Commons licence; whether it meets "nothing beyond credit" has to be decided on the text.
- The engine's own humanoid retargeting on import (bone maps to a standard humanoid profile); confirm in the 4.7.2 docs.
- [repo] Traverser for Unity (MIT) and Splash Damage's Brink talks are named in the brief for move design and contact.

**Out of scope.** Buying, signing up or accepting terms (pause for Nick). Building menus. Changing movement numbers. Reading GPL source.

---

## 4. Traversal: finding and performing the five moves

**Verdict:** Fable, later. Needs #6's body, and #7's recordings for its strips and fuzz.

**Goal.** Vaults, ledge climbs, wall runs, slides and landing rolls on the placeholder body, in both views, that start at once, keep momentum through chains and fail only when the player erred; and the measured `docs/metrics.json` that every obstacle will be sized from.

**Why it's hard.**
- Detection in arbitrary geometry gives false positives: a vault when the player meant to jump, a ledge grab in the middle of a wall run, corners, inclines, thin ledges at speed.
- Detection must give the same answer on the gray-block course and on the dressed one. Dress is laid "over that same course"; if dressed rock changes what is detected, every recorded run and leeway number breaks. Decide early whether detection reads authored markers on kit pieces, the collision shapes, or both.
- Generous and safe pull against each other. The main route needs 150 ms of take-off leeway per obstacle; ten minutes of random input must end with zero stuck states, zero falls through the world and zero non-finite values.
- Inputs must stay human: no recorded run may change more than 8 actions in any second, so a chain cannot need a button per tick.
- There is no character yet. Moves must work as motion on a plain body, then survive being graded again with the real one.
- `docs/metrics.json` is fixed when this module closes. A later change re-runs every grade, route, leeway and flow check and can reopen `kit` and every course.
- People judge the feel. `kit` and every course wait on `docs/playtest/traversal.md`.
- All of it must be tick-deterministic so recordings replay.

**Read first.** #6's and #7's code and records; `docs/decisions/tick-and-frame.md`, `multiplayer-readiness.md`; `ARCHITECTURE.md` (measured events: take-off, stuck state, fall through world; API: `Traversal`, `move_started(kind)`, `move_finished(kind)`); brief item 2 on the metrics course and the movement-number proofs.

**Binding constraints.** Input to motion ≤ 50 ms at p95; fuzz as above; course rules (grades at 65% and 85% of the limit); events and API as in `ARCHITECTURE.md`; per-player state only; moving things are pure functions of the world tick; independent of the active camera; a view switch in the middle of a move must work.

**Done means.**
- `docs/decisions/traversal-detection.md` complete.
- The movement-number instrument proved as the brief says: the jump against a body launched at a known speed under known gravity; ledge reach and wall run by the largest stepped piece that succeeds and the first that fails.
- `docs/metrics.json` with longest jump at a full sprint, highest ledge reach, longest wall run and top speed, measured on the metrics course.
- A detection fixture with known answers: cases that must trigger and cases that must not, all classified correctly.
- First-person and third-person frame strips of every move on the metrics course.
- The fuzz run on the metrics course with traversal on: three zeros.
- Input to motion for a move start within 50 ms at p95.
- Evidence under `docs/evidence/traversal/round-1/`. The playtest build, its `PLAYTEST.md` and the critic round are the main builder's.

**Known leads.** Named by the brief, licences as read when it was written and to be confirmed: Jeh3no's state-machine first-person controller (MIT, GDScript); DeiranZ's parkour first-person controller (MIT, GDScript); NOSHOT (MIT, C#, so anything taken is ported); Gab-ani's Parkour and Advanced Movement (code MIT, animations not free to ship); Traverser (Unity, MIT); the Brink freedom-of-movement talks. anandamous's ParkourCharacterController is GPL-3.0 and off limits. Prefer adapting a proven one; writing from scratch needs its reason in the record.

**Out of scope.** Kit pieces, courses, the human character and its animation, the playtest build, changing the body's numbers without a note to the main builder.

---

## 5. Course-run solver and the kit instruments

**Verdict:** Fable, later. Stage 2, and only once `traversal` has closed and `docs/playtest/traversal.md` exists.

**Goal.** A tool that, for any course, produces a recorded run a person could have played, and the instruments that judge it: route completion under jitter, leeway, input rate, flow and grades.

**Why it's hard.**
- It is a search over three to five minutes of control at 120 ticks a second, with a hard cap of 8 action changes in any second.
- It must aim for the middle of every timing window. A main route's run has to complete 20 times out of 20 with each input shifted by a seeded amount of up to 16 ms either way.
- Leeway is easy to define wrongly. `ARCHITECTURE.md` defines it as the contiguous set of take-off tick shifts for which the run still completes. If the inputs after a shifted take-off stay at their old times, the rest of the run desynchronises and a generous obstacle reads as a tight one. The instrument needs a stated rule for what moves with the take-off, proved on the gap whose window can be calculated.
- Flow constrains layout and solver together: 60% of the run at or above 70% of top speed, no stop longer than 1 s, on a route of 1.5 to 2.5 km run in three to five minutes. [inference] That is an average of 5 to 14 m/s.
- Black lines must beat the main route's time, and still complete unjittered with 50 ms of leeway.
- Runs are judged on the Neo in the end. If a recording made here plays out differently there (#7), completion has to be re-solved or re-recorded per machine, and that has to be designed in.
- The checks must take any course, not only the four levels, so a later seeded mode stays possible (Rules).

**Read first.** Brief item 1 (course rules, budget lines from `kit`), item 2 (instrument proofs); `ARCHITECTURE.md` measured events; #7's record and recording format; `docs/metrics.json`; the traversal playtest file.

**Binding constraints.** The numbers above; grades recomputed from measured size must match the grade a piece carries; kit pieces carry size and grade as data; no input a human could not give; hazards are functions of the world tick.

**Done means.**
- `docs/decisions/course-runs.md` complete.
- Each instrument proved on the fixture the brief names: route completion on a course with one impossible gap, which must fail; input rate on a synthetic recording of known rate; leeway on a gap with a calculable window; flow on a synthetic speed trace; grades on pieces of known grade.
- A solved run on the metrics course and on a fixture course holding every move kind, passing 20 of 20 under jitter, inside the input-rate cap, with its leeway per obstacle logged.
- The same run sent through `remote neo bench`, with the log saying whether it completed there.

**Known leads.** [inference, untested] A closed-loop bot that plays the course in the engine from waypoints and has its inputs recorded, then checked open-loop under jitter, avoids searching raw input space. The brief warns against "a second formula derived from first principles after the first failed instead of looking at what a working project does": look for how existing speedrun or tool-assisted tooling does this before inventing.

**Out of scope.** Designing the four levels. Changing traversal or the movement numbers. Moving the leeway, flow or input-rate numbers (Nick's, after a playtest).

---

## 6. Player body, movement numbers, input latency, fuzz

**Verdict:** Fable, now. It needs only `core`'s interfaces, which exist, and none of the git-ignored art, so a worktree is enough.

**Goal.** `PlayerBody` under `game/movement/`: a body that sprints, jumps, steers in the air, handles slopes, steps and moving surfaces and keeps its momentum, independent of any camera; with the `player-body`, `movement-numbers` and `input-latency` records, the metrics course, and the input-to-motion and fuzz instruments proved.

**Why it's hard.**
- Everything later is sized from this body, and feel is judged by people. Numbers must sit between what a trained athlete does and what is good to play. [inference] The route sizes imply an average of 5 to 14 m/s, which bounds top speed.
- The loop is 120 ticks a second with the engine's physics interpolation on and the jitter fix off (`tick-and-frame`). Interpolation costs up to a tick of delay, and the budget is 50 ms at p95 from the engine receiving input to the body's first movement on screen.
- That budget is measured differently on each machine. [repo] The laptop is paced at 120 Hz and cannot turn vsync off; the Neo is 60 Hz.
- "Independent of any camera" and "direction follows where I look" pull apart. The facing the body moves along has to be simulation state fed by the input source's `look_x`, not read from a camera node. [repo] `DeviceInput` already accumulates look between ticks and hands it over once per tick.
- Random input for ten minutes finds every corner. Stuck is defined as under 1 cm of movement in 3 s while input asks for movement; walls meeting at an angle, step edges and slope seams are where it happens.
- Falls through the world at sprint speed on the terrain's height-map collision or on thin ledges.
- [unverified lead] The engine's character body gives slopes and floor snapping but, as the briefer recalls, no built-in step-up. Confirm in the 4.7.2 class reference before designing around it.
- Moving surfaces must carry the body, and they are pure functions of the world tick.
- No code may assume one body. A ghost is a body with collisions against other players off; a level must hold 8.
- The verification runner cannot drive a body yet. [repo] `game/verify/verify.gd` handles stills, camera paths and window sequences only; there is no input harness and no run preset. This brief has to add them, injecting through the engine's input map.

**Read first.** `game/core/input_source.gd`, `device_input.gd`, `input_defaults.gd`, `players.gd`, `player_slot.gd`, `game.gd`; `game/project.godot` (physics section); `docs/decisions/tick-and-frame.md`, `multiplayer-readiness.md`, `verification-rendering.md`; `ARCHITECTURE.md` (API for `movement`, measured events); `game/verify/verify.gd`, `frame_stats.gd`; `tools/verify.py`; `docs/fixtures/README.md`.

**Binding constraints.** Input to motion ≤ 50 ms at p95. Fuzz: 10 minutes of seeded random input on the metrics course, zero falls through the world, zero stuck states, zero non-finite values. API as written: `PlayerBody` (`CharacterBody3D`), `set_input_source(src)`, `velocity`, `state`, events `jumped`, `landed(speed)`, `left_ground`. All simulation on the tick, reading only the input source. Metres, seconds, kilograms. Frame budget still holds with a body in the scene.

**Done means.**
- The three records complete, and the `ARCHITECTURE.md` table updated.
- `docs/fixtures/` holds the metrics course: flat ground with gaps, walls and ledges in stepped, known sizes.
- Input-to-motion instrument proved against a fixed synthetic delay, then the body measured: p95 ≤ 50 ms, with keyboard and with a gamepad event.
- Fuzz instrument proved on a fixture with a deliberate hole in the floor, which it must find; then the 10-minute run on the metrics course: three zeros.
- The jump proved against a body launched at a known speed under known gravity.
- A showcase preset that exercises only the body, with frame strips; evidence under `docs/evidence/movement/round-1/`.
- Two bodies driven by two input sources in one scene, zero engine errors.

**Known leads.** As in #4: Jeh3no (MIT), DeiranZ (MIT), NOSHOT (MIT, C#), the GDQuest third-person controller (code MIT; its art is excluded), all to be confirmed. Godot's own docs and demo projects (MIT). Adopt and improve before writing from scratch; improvements worth giving back go in `docs/upstream/<project>.md`.

**Out of scope.** Vaults, climbs, wall runs, slides and rolls (#4). The camera rig. The recording format beyond what fuzz needs (#7). The human model. `docs/metrics.json` itself, which is written when `traversal` closes.

---

## 7. Replay, determinism and ghosts

**Verdict:** Fable, later: straight after #6's body passes fuzz. The same agent can carry on into it.

**Goal.** The recorded-run format and `RecordingInput`, proof that a run replays to the same result on the same machine, a measured answer to what survives a move to another machine, and a ghost that plays back anywhere.

**Why it's hard.**
- Hidden sources of difference: anything in `_process` leaking into the simulation (camera smoothing that steers the body), the order nodes or dictionary keys are visited, physics running on more than one thread, start state that is not fully reset.
- Test mode advances exactly two ticks per drawn frame (`--fixed-fps 60`); a normal launch does not. The brief requires the same preset captured both ways to match, and that pair is evidence.
- Across machines it is not guaranteed. [repo] `multiplayer-readiness` already rejects lockstep because Jolt and floating point need not agree between arm64 and x86_64. The benchmark mode must say, per recorded run, whether it completed on that machine.
- That collides with the budgets: route completion, leeway and flow are judged on the Neo. If recordings made on the laptop diverge there, #5 needs to know now, not at stage 2.
- A ghost therefore cannot be inputs. It stores what was seen (transforms, move events, the look), small enough to save, and shaped so a live remote player could take its place.
- Five minutes at 120 ticks is 36,000 samples; storage and interpolation both matter.
- The leeway instrument later needs to shift one take-off inside a recording, so the format has to make that a clean operation.

**Read first.** #6's code; `ARCHITECTURE.md` (Recorded run, Ghost, Determinism); `docs/decisions/tick-and-frame.md`, `multiplayer-readiness.md`; brief item 2 on test mode against a normal launch and on the benchmark mode.

**Binding constraints.** Recorded run holds level id, game version, seed, tick rate, start state, the look and per-tick action states. Saved data under `user://` only. A ghost wears the look of the player who ran it. Nothing rules out a network input source later.

**Done means.**
- `docs/decisions/replay.md` complete.
- One recording replayed 20 times on this machine: the per-tick state hash is identical every time, with the hash log as evidence.
- The same recording in test mode and in a normal launch: identical end state.
- The same recording through `remote neo bench`: completed or not, and the first tick at which it differs, in the log.
- A ghost recorded here plays identically on both machines.
- A known-answer fixture that breaks determinism on purpose, which the check must catch.

**Known leads.** [repo] The decisions already made: tick-only simulation, jitter fix off, seeded randomness, timer counted in ticks. The brief's named controllers for how they record input, licences to be confirmed.

**Out of scope.** Networking. Best times, medals and the race itself (`rules`). The solver (#5).

---

## 8. The two cities: skyline, building records, block generator

**Verdict:** Fable, later: at stage 3 start. `landforms` marks the city sources "undecided — chicago-course".

**Goal.** Choose and prove the data and the generator for Chicago and New York: the real skyline as backdrop from Geological Survey lidar, invented rooftop blocks in each city's real pattern, and gray-block rooftops a course can be laid on.

**Why it's hard.**
- Licence first. City open-data terms must ask for nothing beyond credit; OpenStreetMap and anything share-alike is out. The terms have to be read and quoted, per dataset.
- Lidar is point clouds, and large. Turning them into a light skyline that is still recognisably the real one, inside 8 M primitives, with tools that are Python only, is real engineering. Any reader library is a tool dependency with its own licence to record.
- "As it is today": check the survey date of each lidar project against the skyline.
- The two cities must be told apart at a glance by someone who knows both. Block size, street grid and the spread of heights have to come from the data, then be invented, not copied.
- About 400 m on a side of runnable roofs, 6 to 12 blocks, designed for parkour first: the course module needs the gray blocks before any dressing exists.
- Everything is made again from a seed, with the source's address and checksum in the repo, and large files kept out of git.
- Collision must stay true to what is seen, and the cities are where baked occluders are planned (`renderer`).

**Read first.** `docs/decisions/landforms.md`, `asset-pipeline.md`, `renderer.md`; `tools/gen/terrain.py`, `tools/fetch_assets.py`; `reference/chicago/`, `reference/newyork/`; brief item 1 on world generation and world sizes.

**Binding constraints.** Public-domain or credit-only data; generated at build time and fixed; same world on every machine; no file over 100 MB in git; memory 4 GB; frame budget; the courses are invented, not copies of real neighbourhoods.

**Done means.**
- The cities part of `docs/decisions/landforms.md` complete, with each dataset's terms quoted in `docs/survey/landforms.md` and entered in `ASSETS.md`.
- A generator under `tools/gen/` that, from a seed, writes a skyline backdrop and a gray-block rooftop set for each city, twice over with identical output.
- A wide still of each backdrop on the `neo` profile with its frame numbers, and the two side by side.
- Block statistics (block size, street width, height spread) for each city, from the data, written beside the generator.

**Known leads.**
- [repo] 3DEP products are public domain: the desert tile's metadata says "All 3DEP products are public domain."
- [repo] The brief names "the building records Chicago and New York publish".
- [unverified lead] Chicago's data portal and New York's open data both publish building footprints with heights; New York has also published a 3D building model. Check each one's terms page.

**Out of scope.** The courses themselves. Dressing, materials, rooftop detail (stage 4). Anything from OpenStreetMap.

---

## 9. Trustworthy Neo numbers on Metal

**Verdict:** main builder, now. It is verify round-2 territory and touches `tools/verify.py`, `tools/remote.py` and `game/verify/`, which are being edited already. It is here so it is not lost: #1 cannot prove its result without it.

**Goal.** A Neo result that can be believed: a non-void run, a memory figure that means something on macOS, and a stated way to break frame cost down on Metal.

**Why it's hard.** All [repo], from the two Neo folders, `docs/neo/2026-11-15-f83c5217a26d/` (first) and `docs/neo/2026-11-15-b0545da5a3c6/` (second):
- Both runs are void. First: other apps in front and one frame of 11,254 ms. Second: display awake, longest frame 148 ms, but `HONESTY.json` lists Finder in front beside the game. Whether that was a real loss of focus or the check misreading has to be settled, or no run will ever count.
- GPU time reads 0 on Metal in both.
- `texture_bytes` reads 9223372036854775807 in every memory reading in both.
- Process memory moves the wrong way. First run: 352.6 MB before the load, 80.0 MB after it. Second run, `verify-empty-still`: 419 MB before, 319 MB after. Return ratios range from 0.62 to 1.40. [inference] `ps -o rss=` is not the process's real footprint on macOS; on a machine where graphics and program share memory, the 4 GB budget can be under-counted or counted twice.
- The first run's window was 1280×800 although fullscreen was asked for; the second got 2816×1762. The picture is rendered at 2408×1506 either way, so the display scales it.
- Empty scenes sit at p50 6.5 to 8.4 ms with vsync off on a 60 Hz panel. Whether that is the real cost of the upscaler and presenting, or pacing, is unknown.
- None of it can be tried at the keyboard: only through the remote loop, only when the Neo has been idle five minutes, with nothing installed on it.

**Done means.** A non-void folder under `docs/neo/`; the frame-limiter and known-texture proofs passing on the Neo itself; the log either carrying a real GPU or per-pass figure on Metal or saying plainly that breakdowns are by ablation; `CALIBRATION.md`; the `neo-proxy` and `verification-rendering` records corrected.

**Out of scope.** Changing any budget. Passing `--now`. Installing anything on the Neo.

---

## Not tough enough for a brief (main builder)

- **verify round 2, the rest:** commit `b0545da` says it covers the showcase with content, the driver in the log and the unused textures in exports; the memory leak-flag proof is in progress in the working tree. What remains is whatever of `docs/critic/verify-round-1.md` is still open, then the round-2 critic.
- **core, closing it:** find where the empty-scene 16.7 to 23 ms frames come from (`docs/NOTES.md` gives the three things to try), then the critic round.
- **look-slice plumbing:** the six presets and benchmark path as files, `above_ground` camera placement, folding the scratch notes into `docs/NOTES.md`, the benchmark-only build.
- **camera:** third-person collision and the view switch are well-trodden; the hard part (a steady first-person view on a full animated body) sits in #3. Borderline: if its first critic round scores low on feel, give it a brief then.
- **kit pieces and grades:** data resources and a recompute check; the hard half is #5.
- **rules:** checkpoints, timer in ticks, restart within 1 s, medals, best times, collectibles, the two-player preset. The slot design already carries it.
- **interface:** menus, HUD, settings, photo mode, free roam, credits, at any window shape. The window rules are already proved on an empty scene.
- **sound:** record decided; footsteps by surface and wind by speed from CC0 sources.
- **course layout for the four levels:** design work that leans on #5's solver and, for the cities, #8's blocks.
- **playtest builds, `PLAYTEST.md`, `CALIBRATION.md` upkeep, `SETUP.md` and `README.md`.**
- **final gate:** the critic's, not a builder's.

---

## Summary

1. Nine tough tasks are briefed, ranked hardest first; the hardest two are the desert slice's frame cost on the Neo (about 31.6 ms of GPU on the laptop against a 6.68 ms proxy limit) and making that slice read as a photograph.
2. Go now: #1 frame budget and #6 player body to Fable agents; #9 trustworthy Neo numbers stays with the main builder and must land before #1 can prove anything on the Neo.
3. Go next, in order: #2 look (after #1's first cost table), #7 replay (after #6), #4 traversal (after #6 and #7); #5 solver, #3 character and #8 cities wait for stages 2 and 3.
4. Not briefable yet: the four dress modules, because look-slice's single critic round decides whether the floor, scope or target moves.
5. Nick's calls: whether to depart from the brief's "one agent builds", whether to start the character search early for lead time, and how many agents to run at once against the weekly allowance.
