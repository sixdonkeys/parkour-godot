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
