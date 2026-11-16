# Presets

One preset per file. Presets are added, never edited; only the critic retires one (in its report, with a reason).

Every look preset and every preset that feeds a budget number uses `"profile": "neo"` and `"resolution": [2408, 1506]` (the Neo's display).

Fields (all optional except `id`, `module`, `scene`):

| Field | Meaning |
|---|---|
| `id` | Unique name; also the evidence folder name |
| `module` | The module this preset belongs to |
| `kind` | `still`, `camera_path`, `run`, `sound`, `window`, `fuzz`, `soak`, `two_players`, … |
| `bench` | `true` to bundle into the benchmark mode of exported builds |
| `showcase` | `true` if this is the module's showcase |
| `scene` | `res://` path of the level or fixture scene |
| `base_scene` | Scene loaded first, standing in for what stays loaded around a level (memory baseline) |
| `camera` | `{position, look_at, fov, near, far}` |
| `camera_path` | Path (repo-relative or `res://`) of a camera path file, format `camera-path/1` (see `docs/fixtures/paths/`) |
| `time_of_day` | Local solar hours, passed to the scene's `set_time_of_day()` |
| `profile` | Quality profile name (`neo`) |
| `resolution` | `[w, h]` pins the rendered picture to that size; `"window"` follows the window |
| `warmup_frames`, `frames`, `still_frame`, `strip_every`, `unload_frames`, `precycles` | Frame counts |
| `max_fps` | Frame limiter (fixtures only) |
| `sound` | `true` to capture the game's audio output to `audio.wav` |
| `window_sequence` | `[{frame, action, …}]`; actions `resize_frac`, `fullscreen_toggle`, `focus_out`, `focus_in`, `mark` |
| `look` | `{environment, view, time}` selects the reference folder for histogram distances |
| `fixture` | Free-form settings passed to the scene's `configure_fixture()` |
| `input_script` | An `input-script/1` script, inline or as a repo-relative path: real input events (keys, gamepad, pointer) delivered through the engine's input map at given physics ticks (`docs/fixtures/README.md`) |
| `input_latency` | Runs the input-to-motion instrument: `{device: "key" \| "joy_axis" \| "joy_button", key \| axis, value \| button, trials, seed}`; the scene must offer `latency_target()` |
| `real_time` | `true` for a preset that measures against the wall clock (input to motion): always a normal launch, never `--fixed-fps` |
| `vsync` | `"enabled"` runs the preset with v-sync on, as the game ships (the harness otherwise asks for it off) |
| `finish_frames` | Frames to draw after the scene's `verify_finished()` turns true, before the still is taken and the preset ends |

A scene may offer `verify_finished()` (the preset ends early when it returns true, and the still is the last frame) and `verify_report()` (its result goes into the log as `fixture_result`). The movement fixture scene (`res://movement/fixtures/movement_fixture.tscn`) documents its own `fixture` block at the top of `game/movement/fixtures/movement_fixture.gd`.

Saving a frame strip disturbs the frames around each save by more than the one frame the instrument leaves out (measured on `movement-showcase`: GPU p95 7.5 ms with a strip every 30 frames, 6.1 to 6.3 ms without). A preset whose frame times are budget evidence should not also save a strip; `movement-run-budget` is `movement-showcase` without one.
