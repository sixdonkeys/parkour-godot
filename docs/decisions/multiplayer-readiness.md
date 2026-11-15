# Decision: multiplayer-readiness

- **Options:**
  1. Design for one player now and refactor when multiplayer comes. Rejected: the brief forbids anything that rules multiplayer out.
  2. Build on Godot's high-level multiplayer (ENet over UDP, `MultiplayerSpawner` / `MultiplayerSynchronizer`) later. Keep the single-player game shaped for it now: players as separate nodes with an input source and an authority id, the world's moving state a pure function of the shared tick, and per-player rules state.
  3. Lockstep: send only inputs and simulate every body on every machine. Rejected for later use: Jolt and floating point aren't guaranteed identical across CPUs (the ThinkPad is x86_64, the Macs are arm64), so lockstep would drift.
- **Sources:** `docs/survey/multiplayer-readiness.md` — godot-docs `high_level_multiplayer.rst`; MultiplayerSynchronizer and MultiplayerSpawner class reference 4.7.2; Engine class reference; the brief.
- **Choice:** option 2. What the single-player build does now:
  - **Players are a list, never a singleton.** `Players` (autoload in `core`) registers each `PlayerSlot`: `player_id`, an authority id (always 1 for now), its `InputSource`, its body, camera rig, `RunRules` (timer, checkpoint, collectibles) and its look. The local human is just the first slot with a device input. Nothing reads "the player"; code asks for a slot by id, or for the slot that owns a body.
  - **Input sources:** `DeviceInput` (the engine input map), `RecordingInput` (a recorded run, used by ghosts and the route checks), and later `NetworkInput`. A body reads one action state per tick from its source and never touches `Input` directly.
  - **Ghosts** are `PlayerSlot`s with a `RecordingInput`, collisions with other players off, and their own look. A live remote player takes a ghost's place by swapping in a `NetworkInput` and an authority id.
  - **World state** (course, hazards, checkpoints' positions, collectible spots) belongs to the level. Moving hazards are pure functions of the world tick (position = f(tick, seed)), so two machines agree given the tick, and only the tick needs syncing.
  - **Per-player state:** whether a collectible is taken is per player. Each slot has its own set, so one player taking a collectible doesn't take it from the other.
  - **Capacity:** a level must hold at least 8 bodies (live players plus ghosts) within the frame budget. Measured by the two-player preset (from `rules`) and, before any level closes, by an 8-body stress preset.
  - **Settings now** that keep the door open: `physics_jitter_fix = 0` (already set by `tick-and-frame`), all simulation in `_physics_process` on the tick, and seeded randomness only.
  - **Networking later:** ENet over Tailscale addresses. Tailscale gives each machine a reachable address, so no router port forwarding. That is an inference from how Tailscale works, to be tested when multiplayer is built.
- **Reason:** option 2 costs little now (a list of slots and an input-source interface) and avoids both a later rewrite and a lockstep design that the mixed arm64/x86_64 machines would break. Making hazards functions of the tick removes the hardest thing to keep in step.
- **Licence:** Godot engine and its multiplayer module (ENet, MIT), when used.
