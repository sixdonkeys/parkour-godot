# Decision: input-latency

What adds delay, in order, between the engine being handed an input event and the picture changing (read from the engine source and docs in `docs/survey/input-latency.md`; the same for a key, a mouse or trackpad move and a gamepad button or stick, which all go through `Input::parse_input_event`):

1. **The event waits in the engine's buffer** until the next turn of the main loop. The loop is "process events, then one iteration", and the buffer is flushed at the end of processing events. So an event that arrives during a frame waits for that frame to finish: 0 to 1 frame, 0 to 8.3 ms at 120 Hz, 0 to 16.7 ms at the Neo's 60 Hz. Flushing more often ("agile" flushing) exists only on Android.
2. **The tick.** The body reads its input source once per physics tick. Ticks run inside the same iteration, after the flush, so an event delivered this iteration is used by this iteration's ticks. At 120 ticks a second there is at least one tick per frame at 60 Hz and one on average at 120 Hz; an iteration that happens to hold no tick adds one frame.
3. **Interpolation.** The frame shows the body between its last two tick positions. The newest tick's movement starts to show in the same frame, but the body is drawn up to one tick (8.3 ms) behind where the simulation has it.
4. **Drawing and presenting.** The frame is rendered and handed to the display server; the instrument stops here, at `frame_post_draw`.
5. **Outside the engine:** the device's own polling, the compositor, the swapchain queue and the panel. No instrument inside the game can see these; the Godot docs ask for a high-speed camera to count them.

- **Options:**
  1. Keep the engine's input path and physics interpolation as they are (decision `tick-and-frame`), read input once per tick, and make the first tick of a response large enough to see.
  2. Turn physics interpolation off for the player's own body, so it is drawn at its newest tick. Removes delay 3, but the body then judders whenever frames and ticks drift apart, which at 60 Hz with 120 ticks is rare and at any other refresh rate is constant.
  3. Move the body in `_process` on frame time. Removes delays 2 and 3 and breaks determinism, replay and the tick-only rule; ruled out by `tick-and-frame`.
  4. Turn input accumulation off and flush the buffer by hand before every tick. On desktop the operating system's events are only collected once per loop turn, so there is nothing new to flush between ticks; it costs CPU and gains nothing here.
- **Sources:** `docs/survey/input-latency.md` — engine source 4.7.2 (`core/input/input.cpp`, `platform/linuxbsd/os_linuxbsd.cpp`, `platform/linuxbsd/wayland/display_server_wayland.cpp`, `main/main.cpp`); class reference 4.7.2 for `Input` and `ProjectSettings`; Godot docs "Fixing jitter, stutter and input lag", "Physics interpolation: introduction" and "Controllers, gamepads, and joysticks". All fetched 2026-11-15. The macOS loop (`platform/macos/os_macos.mm`) was read and has the same order: process events, then `Main::iteration()`.
- **Choice:** option 1, with these parts.
  - **One sample per tick, from action states.** `DeviceInput.sample()` reads `Input.get_action_strength` for the movement actions and hands over the look accumulated since the last tick. The body never handles events itself, so a key press and a stick push take the same path and the same time.
  - **A start the eye can see.** From rest, the first tick of movement input sets the body moving at 1.5 m/s at once (`MovementTuning.start_speed`), then acceleration takes over. Without it the first tick moves the body 1.4 mm, which is under a pixel in third person; with it the first tick moves 12.5 mm.
  - **120 ticks a second** (already chosen) keeps delays 2 and 3 to a tick each.
  - **Gamepad.** Stick axes are bound to the same actions with a dead zone of 0.15 per axis; the body then applies a round dead zone of 0.2 to the stick as a whole and rescales, so a worn stick doesn't walk the body and a light push still registers.
  - **V-sync stays the player's setting.** It is on by default (no tearing). Double-buffered v-sync (`rendering/rendering_device/vsync/swapchain_image_count` = 2) would take a frame off delay 5, but the docs warn it halves the frame rate whenever a frame misses, and the Neo's frame budget sits exactly at its 60 Hz refresh. Not taken now; to be looked at again when a level holds its frame budget on the Neo with room to spare.
  - **The instrument** (`game/verify/input_latency.gd`) injects a real `InputEventKey` or `InputEventJoypadMotion` with `Input.parse_input_event` from a thread, at a seeded random moment inside a frame, exactly as the operating system's event would arrive. It records three stamps: injection, `_input` delivery, and the `frame_post_draw` of the first frame in which the body's drawn (interpolated) position differs from where it stood. `ARCHITECTURE.md` defines the budget from `_input`; the log gives that histogram and the longer one from injection, and **the budget is judged on the longer one**. It also reports the time until the body has visibly moved 1 cm.
  - **Proof.** A fixture body that moves a fixed 100 ms after `_input`, by the wall clock: every reading must lie between 100 ms and 100 ms plus two frames, and a second run at 40 ms must read 60 ms lower at the median, within one frame.
- **Reason:** the engine's path costs at most one frame of waiting, one tick and one frame of drawing: about 25 ms at 120 Hz and 42 ms at 60 Hz in the worst case, inside the 50 ms budget without giving up smooth motion (option 2) or determinism (option 3). The start speed is what makes the budget mean something to a player: the brief says "first movement on screen", and a movement under a pixel is not on screen. Judging on the injection stamp keeps the number honest about the wait in the buffer, which the `_input` stamp cannot see.
- **Licence:** Godot engine, MIT. Godot docs, CC BY 3.0 (quoted for study only).

## Measured (2026-11-15, development machine; `docs/evidence/movement/round-1/movement-input-motion-*/log.json`)

Proxy numbers from the Fedora laptop (Apple M1 Pro, Honeykrisp), 200 trials each, at commit `a8290d1`. Milliseconds. "Handed to engine" is the stamp before `Input.parse_input_event`; the budget (50 ms at p95) is judged on the first column.

| Case | Trials | Handed to engine → first motion drawn (p50 / p95 / max) | `_input` → first motion drawn (p50 / p95) | Wait in the engine's buffer (p50 / p95) | `_input` → tick (p50) | Handed to engine → 1 cm drawn (p95) | Within 50 ms at p95 |
|---|---|---|---|---|---|---|---|
| Key (W), this machine's 120 Hz display, v-sync on | 200 | 13.5 / 24.5 / 36.3 | 8.3 / 16.7 | 4.6 / 10.9 | 0.43 | 30.1 | yes |
| Gamepad stick, 120 Hz display, v-sync on | 200 | 13.2 / 21.8 / 30.2 | 8.2 / 15.5 | 4.4 / 10.5 | 0.43 | 27.6 | yes |
| Key (W), frame limiter at 60 fps | 200 | 14.6 / 22.8 / 24.4 | 6.5 / 8.2 | 8.2 / 16.0 | 0.61 | 22.8 | yes |
| Gamepad stick, frame limiter at 60 fps | 200 | 14.9 / 22.8 / 25.9 | 6.4 / 8.1 | 8.7 / 16.3 | 0.61 | 22.8 | yes |

- The tick follows `_input` by under a millisecond: the event is used by a tick in the same turn of the loop, as the source reading said.
- The frame limiter is not the same thing as a 60 Hz display with v-sync: it sleeps before the loop turns, where v-sync blocks at the end of drawing. The 60 fps rows show the wait in the buffer doubling; the Neo's own number comes from the benchmark build (`movement-input-motion-key` and `-pad` are benchmark presets).
- The instrument's proof: `docs/evidence/movement/round-1/proofs/input-motion.json`.

## Measured on the Neo (2026-11-15, `docs/neo/2026-11-15-0a24599c3093/`, a valid run)

60 Hz, v-sync on, Metal, 200 trials each, zero engine errors. Milliseconds.

| Case | Handed to engine → first motion drawn (p50 / p95 / max) | `_input` → first motion drawn (p50 / p95) | Wait in the engine's buffer (p50 / p95) | `_input` → tick (p50) | Within 50 ms at p95 |
|---|---|---|---|---|---|
| Key (W) | 25.3 / 32.1 / 33.2 | 16.4 / 16.9 | 8.8 / 15.9 | 0.5 | yes |
| Gamepad stick | 25.1 / 32.5 / 33.5 | 16.5 / 17.0 | 8.4 / 16.1 | 0.4 | yes |

This is the chain the record describes: up to one frame in the buffer, then one frame to draw; the worst trial is two frames. The 1.5 m/s start means the first drawn movement is already more than a centimeter, so "first motion" and "visible motion" are the same frame at 60 Hz. The comparison with the laptop's numbers is in `CALIBRATION.md` beside the result folder.
