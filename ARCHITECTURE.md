# Architecture

This is the design of an original 3D parkour game (working title **Ridgeline**) built in Godot from `BUILD-BRIEF.md`. The brief is the contract; this file carries every rule and number the brief fixes, unchanged, plus the choices the brief leaves to the builder. It is kept current: a hard problem's choice lands here in the same commit that completes its decision record.

## Goal

**Nick, 2026-11-15:** "i want this to look and feel like a AAA title. within the boundaries we have set on performance and hardware requirements."

So the target is AAA look and feel inside the `neo` profile's performance budget and the 8 GB Neo. This sits alongside the brief's quality floor (any paused frame passes for a photograph; every move responds at once and fails only when the player erred) and doesn't loosen any number. When a choice trades effort for polish (animation quality, camera feel, sound, materials, lighting), the default is the AAA option that fits the budget, not the first one that works.

## Stack

- Engine: **Godot 4.7.2** (`4.7.2.stable`), the same version on every machine, with export templates of that exact version. Moving to a newer one is a decision with its own record, made on every machine at once.
- Language: GDScript for all game code. Tools outside `game/` (the verification orchestrator under `tools/`) are Python 3 with numpy and Pillow; they are never shipped.
- Physics: the engine's built-in Jolt (`physics/3d/physics_engine = "Jolt Physics"`).
- Linux runs as a native Wayland client (`display/display_server/driver.linuxbsd = "wayland"`); X11 is not a target.

## Folder layout

```
BUILD-BRIEF.md      the contract (never edited by the builder)
ARCHITECTURE.md     this file
ASSETS.md           every dependency and asset, with licence statements quoted
SETUP.md            tools each machine needs, with the check command
README.md           how a person opens, runs, verifies and ships the game
game/               the Godot project root (the only thing imported or shipped)
  core/ movement/ traversal/ camera/ character/ kit/ rules/ interface/
  desert-course/ desert-dress/ mountain-course/ mountain-dress/
  chicago-course/ chicago-dress/ newyork-course/ newyork-dress/
  verify/           in-game half of the verification tool (capture, benchmark mode, instruments)
  profiles/         quality profiles, one file per profile (neo.tres ships)
  thirdparty/       adopted code, one folder per project, upstream commit recorded
tools/              out-of-game verification orchestrator, build step, generators (Python)
reference/          photographs graded against; never imported or shipped
docs/               state, decisions, survey, presets, fixtures, evidence, critic reports
builds/             exported builds (git-ignored)
.local/             engine settings, caches, saved data and export templates for development (git-ignored)
```

`game/.gdignore` is not used; instead `reference/`, `docs/`, `builds/`, `tools/` sit outside `game/` so the engine never sees them.

## Modules

| Module | Folder | Owns | Depends on |
|---|---|---|---|
| verify | `game/verify`, `tools/` | capture tool, presets runner, instruments, build step, benchmark mode, reference set | — |
| core | `game/core` | run state, the game loop, saved data, events, the window and the quality profile | verify |
| look-slice | `game/look_slice` (probe, never shipped in a game build) | desert patch probe | core |
| movement | `game/movement` | the player's body and its momentum, independent of any camera | core |
| camera | `game/camera` | first-person and third-person views and the switch between them | movement |
| traversal | `game/traversal` | finding and performing vaults, ledge climbs, wall runs, slides and landing rolls | movement, camera |
| kit | `game/kit` | parkour pieces sized from measured movement numbers, difficulty grades, moving hazards, gray-block layout tools | traversal |
| rules | `game/rules` | checkpoints, timer, restart, medals, best times, ghosts, collectibles | movement, core |
| interface | `game/interface` | menus, HUD, settings, look-change screen, photo mode, free roam, credits, sound | rules |
| character | `game/character` | the human model, its animation, hands and feet meeting the world, choosable looks | traversal, interface |
| desert-course, mountain-course, chicago-course, newyork-course | `game/<env>_course` | gray-block course, no scenery | kit, rules |
| desert-dress, mountain-dress, chicago-dress, newyork-dress | `game/<env>_dress` | terrain, materials, lighting, sky, set dressing over the same course | the matching course |
| final | — | the final gate | everything |

Godot folder names use underscores (`desert_course`) because hyphens are awkward in GDScript class paths; the module names stay as the brief gives them.

Build order (item 3): (1) verify; (2) core; (3) look-slice; (4) movement, camera; (5) traversal; (6) kit; (7) rules; (8) interface; (9) desert-course; (10) character; (11) mountain-course, chicago-course, newyork-course; (12) desert-dress, mountain-dress, chicago-dress, newyork-dress. Until `character` closes, a plain placeholder body stands in.

### Environments

- `desert`: the Sonoran Desert country around Tucson, Arizona, which gets mountainous: the level climbs from the desert floor, through a canyon section, into terrain like the road up Mount Lemmon, and includes a rock outcrop of the kind at Javelina Rocks Overlook, invented, not copied.
- `mountain`: the Black Hills of South Dakota.
- `chicago`, `newyork`: each city as it is today. Chicago and New York must be told apart at a glance by someone who knows both.

Every course is invented, not a copy of real trails or streets; what is real is the look: the landforms, rock, plants, light, building types, materials and rooftop details of that place, for the two terrain levels the broad shape of the land, and for the two cities the skyline and the pattern of the blocks.

### World sizes

- `desert` and `mountain`: roamable ground about 1 km on a side. `chicago` and `newyork`: about 400 m on a side of runnable rooftops, some 6 to 12 blocks. Beyond that the place carries on to the horizon as unreachable backdrop.
- Each main route is 1.5 to 2.5 km long, a run of three to five minutes. Real heights are compressed: the desert level climbs some 150 to 300 m.
- The quality floor holds along every route and at every challenge spot. Off them, free roam must still read as the place, with no holes, bare patches or visible edge of the world, though it may repeat more.
- These sizes are targets that `look-slice` tests on the Neo before any level is built; if the Neo can't carry them, that is a conflict for `docs/WAITING.md`.

### World generation

The worlds are generated once, when the game is built, and then fixed. Nothing about a level is generated while the game runs, and every player on every machine gets the same world. The terrain levels start from USGS public-domain elevation data (Tucson country for `desert`, the Black Hills for `mountain`), compressed to the sizes above (Nick's choice, fixed). Rules and a seed place scatter and city block bulk. City skyline backdrops come from USGS public-domain lidar; runnable rooftops are invented blocks in the city's real pattern, with block sizes, grid and height spread from lidar and the city building records where their terms fit the asset policy. OpenStreetMap and other share-alike data are not used. The generator, its seed and the address and checksum of its source data are in the repository. Details: decision `landforms`.

## Units and conventions

- Metres, seconds, kilograms; one engine unit is one metre.
- Godot axes: +Y up, −Z forward. Angles in radians in code, degrees in data files meant for people.
- Time of day as decimal hours, local solar time of the place (e.g. `13.0`, `18.25`).
- Files: snake_case `.gd`, one class per file; signals past tense (`checkpoint_reached`).
- JSON for logs, presets, fixtures and recorded runs; `.tres` for quality profiles.

## Shared data model

World state and player state are kept apart from the start (multiplayer is coming).

- **World** (one per loaded level): level id, the course (pieces, routes, checkpoints, collectible spots, hazards), hazard state driven only by the shared simulation tick, the seed used for anything seeded.
- **Player** (zero or more per world, each identified by a `player_id`): its own body, input source, camera rig, timer, checkpoint, collectibles, look, run recording. Nothing in the code assumes exactly one player; the local human is just `players[0]` with a device input source.
- **InputSource** (per player): a device source (the engine input map), a recording source (a recorded run), or later a network source. Bodies read only from their input source.
- **Ghost**: a Player whose input source is a recording and whose collisions with other players are off. A live remote player could take a ghost's place by swapping the input source.
- **Look**: a small dictionary (body, skin, hair, clothing, colours) saved with the player's data and stored in each ghost.
- **Recorded run**: level id, game version, seed, tick rate, start state, the look, and per-tick action states. Format: decision `replay`.
- **Kit piece**: a resource carrying its kind, measured size, grade and anchor data, readable by a future seeded course generator.
- **Saved data**: `user://` only (best times per level and player, ghosts, look, settings).

## Public API and events

The API grows as modules are built; each entry is filled in by the commit that builds it.

- `core`: autoload `Game` (`Game.run_state`, `Game.load_level(id) -> Error`, `Game.unload_level()`, `Game.quality` (the active profile), `Game.events` (the event bus)); autoload `Save` (`Save.read(key, default)`, `Save.write(key, value)`); `WindowRules` (pointer capture and focus handling). Events: `level_loaded(id)`, `level_failed(id, error)`, `level_unloaded(id)`, `run_paused`, `run_resumed`, `focus_lost`, `quality_changed(profile)`.
- `movement`: `PlayerBody` (`CharacterBody3D`): `set_input_source(src)`, `velocity`, `state`; events `jumped`, `landed(speed)`, `left_ground`.
- `traversal`: `Traversal` on a body: events `move_started(kind)`, `move_finished(kind)`.
- `camera`: `CameraRig`: `set_view(FIRST|THIRD)`, `toggle_view()`; event `view_changed(view)`.
- `rules`: `RunRules` per player: events `checkpoint_reached(i)`, `fell`, `restarted`, `finished(time)`, `collectible_taken(id)`.
- `interface`, `character`, `kit`, levels: filled in when built.

## Determinism

- Seeded RNG only (`RandomNumberGenerator` with an explicit seed); no `randf()` on the global generator anywhere in game code.
- A test mode with fixed timing: the simulation runs a fixed number of physics ticks per drawn frame regardless of wall clock (decision `tick-and-frame`).
- A recorded run replays to the same result on the same machine.
- Test mode differs from a normal launch only in seed and timing; the pair is captured as evidence.

## Measured events

Each number in the budget is defined by the engine state its instrument reads.

- **Frame time**: wall time between consecutive `RenderingServer.frame_post_draw` signals (CPU wall clock, `Time.get_ticks_usec()`), plus GPU time from `RenderingServer.viewport_get_measured_render_time_gpu()` logged beside it.
- **Memory**: process resident size (as the OS reports it; see decision `verification-rendering`) plus `Performance.RENDER_VIDEO_MEM_USED`. Readings are taken before load, after load and after unload, with the session's base scene (the menu's 3D backdrop) already up, so render buffers that live for the whole session are in the baseline. The "pre-load figure" for the 5% return is the reading after one earlier load/unload cycle of the same level. The engine keeps its upload staging buffer (bounded by `rendering/rendering_device/staging_buffer/max_size_mb`, 128 MB) once it has grown, so a first-load figure would count a one-off pool as level memory. A leak still shows: the instrument reports the raw first-load return, the after-unload figure of every cycle, and flags `grows_each_cycle` when the last unload is more than 1% above the one before it. On the stress scene the process heap settled over the first two cycles (496 → 507 → 511 → 507 MB after each unload) while video and engine-tracked memory stayed flat.
- **Build size**: bytes of the exported macOS artifact on disk.
- **Input to motion**: from the `Time.get_ticks_usec()` stamp when the engine delivers an input event to the game (`_input`) to the `frame_post_draw` of the first frame drawn after the body's position changed because of it.
- **Fall through world**: a body below the level's kill plane while not in a fall the course expects, or a body inside static collision.
- **Stuck state**: a body whose position changes by less than 1 cm over 3 s while its input asks for movement and no move is in progress.
- **Non-finite value**: any NaN or infinity in a body's position, velocity or camera transform.
- **Route completed**: the player's `finished` event fires with all route checkpoints taken in order.
- **Take-off**: the physics tick on which a body leaves the ground or starts a traversal move because of a jump or move input.
- **Leeway**: the width in milliseconds of the contiguous set of take-off tick shifts around the recorded take-off for which the run still completes.
- **Restart time**: from the `fell` event to the tick the body accepts input at the checkpoint.
- **Flow**: fraction of the run's ticks with horizontal speed ≥ 70% of `top_speed` from `docs/metrics.json`; a stop is any span with horizontal speed < 0.5 m/s.
- **Input rate**: count of changes in action state in any sliding one-second window of a recording.
- **Clipping**: any output sample at or above 0 dBFS.

## Course rules

- Every obstacle is sized from the movement numbers in `docs/metrics.json` (longest jump at a full sprint, highest ledge reach, longest wall run, top speed), which are fixed when `traversal` closes.
- Grades: green tests up to 65% of the limit, blue up to 85%, black above that, or any chain of three or more moves with nowhere to stand between them.
- Each level has a main route of green and blue obstacles only, at least two black lines (optional shortcuts that beat the main route's time), and at least three challenge spots off the main route, each holding a collectible that the level's results screen counts.
- Anything that moves belongs in the place: a crumbling ledge, a rolling log, a swinging crane hook.

## Window rules

The game is tied to no window manager. It must sit as well in tiling ones such as Niri and Umbriel, which give a window whatever size and shape they choose, as in GNOME; those three are the ones checked:
- Any size or shape the window is given is taken at once: the picture fills it without stretching and the interface stays readable and inside it, from a narrow column to a wide strip. The game never asks for a size, a position or a display mode of its own.
- One window, with a stable application ID and title that window rules can match. No splash or helper windows.
- Fullscreen is a toggle, and leaving it returns the window to its tile.
- The pointer is held only during play in a focused window. Pausing, opening a menu or losing focus lets it go at once, and losing focus pauses a run.
- The window manager's shortcuts always get through: nothing is bound to the Super key and the keyboard is never grabbed.

Application ID and title: both `Ridgeline` (Godot uses `application/config/name` as the Wayland app ID; decision `windowing`).

## Performance budget

Each number with the first module at which its instrument has something to measure:
- Frame time: on the `neo` quality profile at the Neo's display resolution, 95% of frames within 16.7 ms and 99% within 22 ms on every benchmark path and recorded run (from `core` on an empty scene; binding for each level from its `-course` module).
- Memory: process plus video memory at most 4 GB with any one level loaded, and back within 5% of the pre-load figure once the level is unloaded (from `core`).
- Build size: the macOS build at most 4 GB (from `core`).
- Input to motion: at most 50 ms at the 95th percentile, from the engine receiving the input to the body's first movement on screen (from `movement`).
- Fuzz: 10 minutes of seeded random input ending with zero falls through the world, zero stuck states and zero non-finite values (from `movement`, on the metrics course).
- Route completion: every main route's recorded run completes 20 times out of 20 with each input's timing jittered by a seeded amount of up to 16 ms either way; every black line's and challenge spot's recorded run completes unjittered (from `kit`).
- Input rate: no recorded run changes more than 8 actions in any one second (from `kit`).
- Leeway, the spread of take-off timing that still succeeds: at least 150 ms on every main-route obstacle, 50 ms on black lines, 33 ms on challenge spots (from `kit`).
- Grades: every obstacle's grade, recomputed from its measured size and `docs/metrics.json`, matches the grade it carries (from `kit`).
- Restart: a fall to back in control at the last checkpoint within 1 s (from `rules`).
- Flow: at least 60% of each main route's recorded run at or above 70% of top speed, with no stop longer than 1 s (from `desert-course`).
- Soak: 10 minutes looping a level ends with frame time and memory within 10% of its first minute (from `desert-course`).
- Window: through a resize across every window-shape preset, a focus loss and a fullscreen toggle during a recorded run, zero engine errors, zero interface elements outside the window, and the pointer released and the run paused on the focus loss (from `core`; the interface check from `interface`).
- Two players: two bodies in one level, each driven by a different recorded run and each with its own timer, checkpoint and collectibles, both finish with zero engine errors (from `rules`).

The Neo (MacBook Neo, Apple A18 Pro, 8 GB shared, 2408×1506) is the machine these numbers are for. A number measured on a development machine stands in only under the `neo-proxy` decision, is labelled proxy in the log, is never judged more leniently than the budget itself, and gives way to the Neo's own number as soon as a result folder from it exists. The ThinkPad T14 must meet the same numbers on the same profile at its own display resolution; where the two pull in different directions the Neo wins and the conflict goes into `docs/WAITING.md`.

For now (harness addendum) the Neo is out of the loop: every number is measured on the Fedora laptop under `neo-proxy`, labelled proxy, and modules close with `neo-unverified`.

Once this file exists, the budget numbers, the course rules and the window rules are the contract. Tightening one is a decision with its own record; loosening one is Nick's call through `docs/WAITING.md`. The leeway, flow and input-rate numbers are starting values Nick may move after a playtest.

## Dependency and asset policy

- Game code in GDScript only.
- Third-party code under MIT, Apache-2.0, BSD, zlib or CC0.
- A native plugin only if it supplies or builds for macOS arm64, Linux arm64 and Linux x86_64 and does not rule out Windows x86_64.
- Shipped assets public domain, CC0, or under a licence that asks for nothing beyond credit (CC BY and the like), with every credit owed shown on a credits screen in the game. Share-alike and non-commercial licences stay out of what ships.
- Every dependency and asset recorded in `ASSETS.md` with its source address, author, licence and the licence statement quoted from the source.
- Every setting that trades looks for speed (render scale, lighting method, shadows, texture and mesh detail, effects) lives in a quality profile, one file per profile in `game/profiles/`; the game ships one profile, `neo`. Source art is kept at the best quality obtained and reduced per profile.
- Adopted code lives in `game/thirdparty/<project>/` with its licence notice and upstream commit; improvements worth giving back are listed in `docs/upstream/<project>.md`.

## Failure isolation

- Levels and optional modules load through `Game.load_level()`, which checks the scene exists, loads it with `ResourceLoader` in threaded mode, and instantiates it inside a guard. On any failure it logs the error (with `push_error` and to `user://logs/`), emits `level_failed`, frees whatever was half-made and returns the player to the main menu.
- The main menu and `core` never preload level or optional-module scenes, so a broken level can't stop the game starting.
- A missing or broken quality profile falls back to the built-in defaults of `neo` and logs the error.
- A corrupt save file is renamed aside (`.corrupt-<time>`) and replaced by defaults; it never stops the game starting.

## Hard problems

Each record lives at `docs/decisions/<problem>.md` with its excerpts in `docs/survey/<problem>.md`. A record is written when the first module that depends on it starts.

| Problem | First module | Status / choice |
|---|---|---|
| verification-rendering | verify | decided — see `docs/decisions/verification-rendering.md` |
| tick-and-frame | verify | decided — see `docs/decisions/tick-and-frame.md` |
| windowing | verify | decided — see `docs/decisions/windowing.md` |
| mac-delivery | verify | decided — see `docs/decisions/mac-delivery.md` |
| asset-pipeline | verify | decided — see `docs/decisions/asset-pipeline.md` |
| sound | verify | decided — see `docs/decisions/sound.md` |
| neo-proxy | verify | decided — see `docs/decisions/neo-proxy.md` |
| renderer | core | decided — see `docs/decisions/renderer.md` |
| quality-profiles | core | decided — see `docs/decisions/quality-profiles.md` |
| multiplayer-readiness | core | decided — see `docs/decisions/multiplayer-readiness.md` |
| lighting | look-slice | undecided — look-slice |
| landforms | look-slice | undecided — look-slice |
| player-body | movement | undecided — movement |
| movement-numbers | movement | undecided — movement |
| replay | movement | undecided — movement |
| input-latency | movement | undecided — movement |
| cameras | camera | undecided — camera |
| traversal-detection | traversal | undecided — traversal |
| course-runs | kit | undecided — kit |
| character-sourcing | interface | undecided — interface |
| animation-contact | character | undecided — character |
| remote-test | verify (reopened for the Neo, 2026-11-15) | decided — see `docs/decisions/remote-test.md` |
