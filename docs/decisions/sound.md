# Decision: sound

- **Options (capture for verification):**
  1. `AudioEffectCapture` on the Master bus: raw float samples of everything the game outputs, in the same run as the pictures.
  2. `AudioEffectRecord` on Master: 16-bit encoded WAV, so clipping above full scale is already lost.
  3. Movie Maker's WAV: exact and deterministic, but non-real-time.
- **Options (sound design):**
  a. Hand-placed `AudioStreamPlayer3D` per source with fixed clips.
  b. A small sound system: buses per kind, footsteps chosen by surface tag, wind and speed layers driven by body speed, a limiter on Master.
- **Sources:** `docs/survey/sound.md` — class reference 4.7.2 for AudioEffectRecord, AudioEffectCapture and Engine; godot-docs `creating_movies.rst`.
- **Choice:** capture option 1 with sound design b.
  - **Capture:** the verify runner puts an `AudioEffectCapture` on Master, drains it every frame and writes a 32-bit float WAV. Peak (dBFS), RMS and clip count are computed from the float samples, where clipping is any sample at or above 0 dBFS. Which sounds played is logged from the game's own sound events with each one's peak. Option 3 is the fallback where no real audio driver is available, and is labelled so.
  - **Buses:** Master (with `AudioEffectHardLimiter` at −1 dBFS), Footsteps, Body (landings, rolls, grabs), Wind, Ambience, Hazards, UI.
  - **Footsteps:** a surface tag on each collider's physics material metadata (`rock`, `sand`, `gravel`, `wood`, `metal`, `gravel_roof`, `tar_roof`, `concrete`, `grass`), with several takes per surface and seeded random variation of take and pitch (±4%). Triggered from the gait cycle (later, from animation contact events).
  - **Wind:** a looping noise bed whose gain and low-pass cutoff rise with the body's speed and height above the ground, plus an air-rush layer on long falls.
  - **Spatial placement:** hazards and ambience are `AudioStreamPlayer3D` with inverse-square falloff and attenuation by distance. The player's own body sounds play non-positional, centred on the listener, which follows the active camera.
  - **Mixing:** fixed bus levels in a resource, a ducking send from Body to Ambience, and a settings slider for each of master, effects and ambience.
  - **Assets:** CC0 or CC BY recordings only, sourced in `interface`, which owns sound.
- **Reason:** only option 1 measures clipping honestly (the samples are floats), in the same run as the stills. The surface-tag and speed-driven design is what makes footsteps and wind respond to play rather than loop blindly. A hard limiter keeps the clip count at zero by construction while the mix is tuned by ear.
- **Licence:** Godot engine, MIT.
