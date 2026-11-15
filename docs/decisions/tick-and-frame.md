# Decision: tick-and-frame

- **Options:**
  1. 60 Hz physics ticks with the engine's built-in physics interpolation.
  2. 120 Hz physics ticks with the engine's built-in physics interpolation.
  3. A hand-rolled fixed step inside `_process` with our own interpolation.
- **Sources:** `docs/survey/tick-and-frame.md` — Engine class reference 4.7.2 (`doc/classes/Engine.xml`); command line tutorial (`--fixed-fps`); physics interpolation tutorials (godot-docs `tutorials/physics/interpolation/`).
- **Choice:** option 2.
  - Settings: `physics/common/physics_ticks_per_second = 120`, `max_physics_steps_per_frame = 16`, `physics/common/physics_interpolation = true`, `physics_jitter_fix = 0`.
  - All simulation (bodies, traversal, hazards, timers, rules) runs in `_physics_process` and reads input only from the player's InputSource, sampled once per tick. Rendering-only work (camera smoothing on top of the interpolated body, effects, UI) runs in `_process`.
  - The run timer counts ticks (time = ticks / 120), so it never depends on frame rate.
  - Test mode passes `--fixed-fps 60`: each drawn frame advances exactly two ticks whatever the wall clock does, while frame-time instruments still read the wall clock of each real frame.
  - The smallest take-off shift the leeway instrument can make is one tick, 8.33 ms.
  - Deterministic: tick-level simulation given the same start state, inputs and binary. Not deterministic, and kept out of the simulation: interpolation, camera smoothing, particles, audio.
- **Reason:** 120 Hz halves the gap between an input and the next tick that can act on it. That helps the 50 ms input-to-motion budget, gives the leeway instrument 8.33 ms steps, and makes fast-moving bodies against thin ledges more reliable. Built-in interpolation removes the stair-step judder a fixed tick causes at any refresh rate, so writing our own (option 3) has no advantage. Turning the jitter fix off follows the engine's own advice for network games, which multiplayer will be.
- **Licence:** Godot engine, MIT.
