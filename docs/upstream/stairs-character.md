# Upstream: stairs-character

- Project: https://github.com/Andicraft/stairs-character (MIT, Andrea Jörgensen)
- Adopted at commit `5403d02f6b64b49a1d1bd7af11dd51a6edfc9e6c` into `game/thirdparty/stairs-character/` (commit `d5e0720`, files as fetched).
- The project has no contribution guide; its one script uses tabs, snake_case and `#` comments, and the changes below keep to that.
- Upstream issues read first: the repository's issue list could not be fetched in this session (only raw files and the repository API were used), so whether either point below is already reported is **not checked**. Check the list before opening anything.
- Opening an issue or pull request is Nick's to do; it posts under his name.

## Changes worth giving back

Each is one commit that touches only `stairs_character.gd` and has nothing of this game in it.

### 1. Test at least a minimum depth onto the step — commit `1f4dd9d` (8 lines)

**What it fixes.** `stair_step_up()` moves the collider forward by what is left of this frame's motion after the wall was touched, then sets it down to see whether it lands on something it can stand on. When the wall is touched at the very end of the frame's motion, what is left is a sliver (a millimetre). The collider is then set down overlapping the step by that sliver, the contact is with the step's edge, the edge's normal fails the `floor_max_angle` check, and the function gives up. `move_and_slide()` then hits the riser as a wall and the character stops dead in front of a step it can climb. With velocity zeroed, the next frame's motion is small again, so it can stay there.

**How it showed up here.** A cylinder 0.6 m across running at 6.4 m/s into a staircase with 0.18 m risers and 0.30 m treads (Godot 4.7.2, Jolt): stopped at the first riser and never climbed; single 0.2 m steps were climbed or not depending on the approach's phase. With the change the same staircase is climbed at full speed with no speed lost (`docs/evidence/movement/round-1/movement-metrics/log.json`, lane `stairs`).

**The change.** A new export `_min_step_depth` (0.1). If the remaining motion is shorter than that, the forward test uses `_min_step_depth` along the direction of travel instead. Only the test moves further; the character's own position is still changed in height only.

**Issue text to open:**

> **Character stops at a climbable step when it first touches the riser at the end of a frame's motion**
>
> `stair_step_up()` tests the landing by moving the collider forward by `result.get_remainder()`. When the wall is touched at the very end of the frame's motion that remainder is tiny, so the collider is set down overlapping the step by a sliver, the down test hits the step's edge, the collision normal fails the `floor_max_angle` check and the step is rejected. `move_and_slide()` then stops the character at the riser.
>
> Repro: Godot 4.7.2, Jolt, cylinder collider (radius 0.3, margin 0.002), stairs with 0.18 m risers and 0.30 m treads, approach at about 6 m/s. The character stops at the first riser; whether it does depends on where in the frame the wall is reached.
>
> Fix I'm using: probe forward by at least a minimum depth (0.1 m) when the remainder is shorter. Happy to send a PR.

### 2. Reuse the motion-test objects — commit `f424a6f` (8 lines)

**What it fixes.** `stair_step_up()` and `stair_step_down()` each create a `PhysicsTestMotionResult3D` and a `PhysicsTestMotionParameters3D` on every call: four allocations per physics frame per character, at whatever the tick rate is (120 a second here, times up to 8 bodies). The change keeps one of each on the node. Every field the functions read is set before each test, so behaviour is unchanged.

**Issue text to open:** none needed; this is a small pull request on its own ("Reuse the PhysicsTestMotion objects instead of allocating them every frame").

## Specific to this game (not for upstream)

Nothing in `stairs_character.gd`. How this game uses the class is in `game/movement/player_body.gd`:

- `PlayerBody` keeps its own ground state and sets `force_stair_step` from it each tick, because right after a step-up the engine's `is_on_floor()` can read false for a tick (the upstream script's own comment warns of this). It calls `stair_step_up()`, `move_and_slide()` and `stair_step_down()` itself rather than `move_and_stair_step()`, to know whether a step was taken.
- The collider is made in `_init()` and named `Collider`, as the class requires.

## Worth telling upstream, no code

- With Jolt, a box's `Shape3D.margin` rounds its edges (default 0.04 m). Steps made of boxes with the default margin have rounded lips, which makes the sliver case above more likely. This game sets the margin of its course boxes to 0.002 m. A line in the upstream README next to "Collider margin should be as low as you can get it" would save the next person the hunt.
