# Fixtures

Known-answer fixtures, one per instrument, each written with its instrument. `python3 tools/verify.py prove <instrument>` runs one and writes `docs/evidence/verify/round-<n>/proofs/<instrument>.json`.

| Instrument | Fixture | Known answer |
|---|---|---|
| Frame time | `verify-frametime-limiter-30.json` | Frame limiter at 30 fps: median frame 33.33 ms (±1.5) |
| Memory | `verify-memory-known-texture.json` | One 4096×4096 RGBA8 texture, no mipmaps: +67,108,864 bytes of texture memory (±5%), back to the baseline after unload, no growth across cycles |
| Build size and packed-file list | `buildcheck/` (a tiny project) | A 10,485,760-byte file is listed at exactly that size; `assets/planted.bin`, not in the fixture's `ASSETS.md`, is flagged |
| Image numbers | synthetic, in `tools/verify.py` | Image vs itself: SSIM 1, histogram distance 0. Grey 100 vs grey 120: SSIM equals the analytic luminance term. A quarter of a grey image blacked out: histogram distance exactly 0.25 |
| Sound | `verify-sound-tone-minus6.json`, `verify-sound-tone-clipping.json` | Sine at amplitude 0.5: peak −6.02 dBFS, RMS −9.03 dBFS, no clipping. Amplitude 1.25: peak +1.94 dBFS, clipping reported |
| Window | `verify-window-sequence-empty.json`, `verify-window-ui-outside.json` | Every shape filled without stretching (a frame grab has the window's own pixel size), zero errors. The interface check reports exactly the one label placed outside |

Instruments that arrive with `movement` (`python3 tools/verify.py prove input-motion|fuzz|jump` writes `docs/evidence/movement/round-<n>/proofs/<instrument>.json`):

| Instrument | Fixture | Known answer |
|---|---|---|
| Input to motion | `movement-latency-delay-104.json`, `movement-latency-delay-37.json` (scene `res://verify/fixtures/latency_delay.tscn`) | A block that moves a fixed 104 ms (37 ms) after the engine delivers the key press, by the wall clock. With frames of P ms the reading from `_input` is (ceil(delay / P) + 1) × P: the median must be within 0.3 P of that, no reading under the delay, none over the delay plus two of the run's longest frame, and the two medians apart by the difference of the two answers within half a frame |
| Fuzz | `movement-fuzz-hole.json` (a 12 m floor with a 2 m hole and nothing under it), `movement-fuzz-solid.json` (the same floor, hole filled), `movement-fuzz-cell.json` (a body shut in a cell 4 mm wider than it is), `movement-fuzz-nan.json` (a NaN put in the body's velocity at tick 600) | Hole: at least one fall through the world, nothing else. Solid: nothing. Cell: stuck states, nothing else. NaN: exactly one non-finite value, nothing else |
| Movement numbers: the jump | `movement-jump-known-launch.json`, `movement-jump-wrong-gravity.json` | A body launched at four known velocities under 10 m/s²: apex vy²/2g, air time 2vy/g, distance = horizontal speed × air time, within 3 mm, one tick and one tick of travel. The same answers asked of a body under 12 m/s²: the instrument must say they don't match |

The metrics course is `metrics-course.json`: flat ground with gaps (3 to 8.5 m), ledges (0.4 to 3 m), single steps (0.1 to 0.5 m), a staircase, slopes (15° to 60°), a ridge and a valley, walls (4 to 12 m long), corners (90°, 60°, 30°), beams (0.2 to 1 m wide), a thin deck (5 cm) under a 3 m tower, a height-map patch and two moving surfaces, all in stepped, known sizes, with lanes for the instruments, spawn points and named regions. It and the three small fuzz courses are written by `python3 tools/gen/metrics_course.py` (arithmetic only, no randomness) and built in the game by `game/movement/fixtures/metrics_course.gd`.

Formats:
- **Metrics course** (`metrics-course/1`): `{id, kill_plane_y, pit_floor_y, expected_fall_below_y, bounds, stepped_sizes, pieces, lanes, spawns, regions}`. A piece is a `box` (`center`, `size`, optional `rot_deg`), a `heightfield` (`center`, `cells`, `cell`, `heights` row by row) or a `mover` (`center`, `size`, `travel`, `period_ticks`, `phase_ticks`). A lane names a measurement (`gap`, `flat`, `ledge`, `step`, `stairs`, `slope`, `carry`) with its start and the sizes the instrument needs. A spawn is `{id, pos, yaw_deg}`, with `on_mover` when it rides a moving surface. Metres, +Y up, ground top at y = 0, lanes run toward −Z.
- **Input script** (`inputs/*.json` or inline in a preset, `input-script/1`): `{events: [{tick, key, pressed} | {tick, joy_axis, value} | {tick, joy_button, pressed} | {tick, mouse: [dx, dy]}]}`. Each entry becomes a real `InputEventKey`, `InputEventJoypadMotion`, `InputEventJoypadButton` or `InputEventMouseMotion` handed to `Input.parse_input_event` at that physics tick, before anything else in the tick runs. Keys are named as `OS.find_keycode_from_string` reads them (`W`, `Space`); axes `left_x`, `left_y`, `right_x`, `right_y`; buttons `a`, `b`, `x`, `y`, `start`.
- **Camera path** (`paths/*.json`, `camera-path/1`): `{id, duration_s, far, keys: [{t, pos: [x,y,z], look_at: [x,y,z], fov}]}`. Positions are interpolated with cubic (Catmull-Rom style) curves; in test mode time advances 1/60 s per frame.
