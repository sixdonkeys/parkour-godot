# Decision: movement-numbers

- **Options:**
  1. An athlete's numbers as they are: real gravity (9.8 m/s²), a jump that lifts the body about 0.5 m, five or six seconds to reach top speed. It would look right on a real human model, but nearly a second of hang time and a slow start feel floaty and unresponsive on a screen.
  2. The numbers the exemplar controllers ship with: 12 to 15 m/s, jumps of 2 m and more, speed reached almost at once. Fun in a gray-block arena; on a photographic course with a realiztic human they read as a superhero, and a 400 m city is crossed in half a minute.
  3. An athlete's sizes on a game's clock: speeds, heights and distances a trained athlete could show, with time compressed (stronger gravity, quick first acceleration) so the body answers at once.
- **Sources:** `docs/survey/movement-numbers.md` — Wikipedia on footspeed, sprinting, the long jump, the standing long jump, the high jump, the vertical jump and parkour (fetched 2026-11-15); the tuning values in Jeh3no's, DeiranZ's, the NOSHOT and the GDQuest controllers, the Godot platformer demo and `stairs-character`; `BUILD-BRIEF.md` item 1 (route length and time, the flow number).
- **Choice:** option 3. The values live in `MovementTuning` (`game/movement/movement_tuning.gd`); nothing else in the game holds a movement number. They are starting values: measured on the metrics course by the movement instrument, judged by Nick and his son in the `traversal` playtest, and only then fixed into `docs/metrics.json`.

  | Number | Value | Where it sits |
  |---|---|---|
  | Top speed | 10.0 m/s | 80% of the fastest speed ever measured (12.42 m/s) and under the 10.44 m/s the world-record 100 m averaged from a standing start; above NOSHOT's sprint (8) and GDQuest (8), below Jeh3no (12) and DeiranZ (15) |
  | Run speed (reached quickly) | 6.0 m/s | Reached in 0.3 s at 20 m/s² so the first step is immediate; the Godot platformer demo's whole top speed |
  | Start speed (given on the first tick from rest) | 1.5 m/s | So the first tick's movement is 12.5 mm and shows on screen (decision `input-latency`); too small to see as a jolt |
  | Build from run to top speed | 2.0 m/s² (2.0 s) | Momentum is worth something: about 2.3 s and 17 m from rest to top speed, against the 60 m a sprinter needs |
  | Brake | 24 m/s² | A stop from top speed in 0.42 s and 2.1 m |
  | Grip (sideways speed shed while turning) | 30 m/s² | A full-speed turn has a 3.3 m radius and loses no speed up to 90° |
  | Sideways and backward speed | 5.1 and 4.2 m/s | 85% and 70% of run speed |
  | Jump height | 0.95 m | Between a standing vertical and what a high jumper's center of mass gains; under half of Jeh3no's 2.0 m |
  | Time to peak, time to fall | 0.34 s, 0.30 s | Jeh3no's model (0.3 and 0.25 for 2 m); gives gravity of 16.4 m/s² rising and 21.1 m/s² falling, and a take-off speed of 5.59 m/s |
  | Jump at full sprint, flat to flat | 6.4 m by arithmetic (10.0 × 0.64 s) | 72% of the long-jump record (8.95 m); to be confirmed by measurement |
  | Air control | 8 m/s², adds speed only up to 4.0 m/s | Enough to turn a jump about 30° or pull it short; a standing jump reaches about 1.6 m |
  | Short hop | gravity × 2.5 while rising with jump released | The Godot platformer demo cuts the jump on release |
  | Coyote time, jump buffer | 12 and 14 ticks (0.10 s, 0.117 s) | Far under Jeh3no's 0.3 s and NOSHOT's 0.5 s: forgiving, not a second jump |
  | Step height | 0.35 m | `stairs-character` ships 0.33; a stair riser is about half that |
  | Walkable slope | up to 46° | The engine's default is 45° |
  | Fall speed limit | 40 m/s | A third of a meter per tick |
  | Body | cylinder 1.8 m tall, 0.3 m radius, 75 kg | See `player-body` |

- **Reason:**
  - Top speed has to fit the routes. The longest route the brief allows, 2.5 km in five minutes, needs an average of 8.3 m/s. At 10.0 m/s a flowing run (83% of top speed on average) makes that, and the shortest (1.5 km) takes three minutes at the same pace, so every route length in the brief fits its time. At 9 m/s the longest routes could not be run in five minutes; at 12 m/s and up a 1.5 km route is over in about two. It also has to look like a person once `character` puts a realiztic human on the body.
  - Jump height and distance are what every obstacle is sized from, so they are kept at what a trained athlete could show: a 6.4 m gap and a 0.95 m ledge are believable in a photograph. Higher ledges and longer reaches are `traversal`'s moves, not a bigger jump.
  - The clock is the game's. Real gravity would hold the body in the air for 0.88 s on a 0.95 m jump; 0.64 s keeps the height and makes the response quick. The exemplars all do this, more strongly.
  - The two-stage acceleration is what makes momentum matter: the first 6 m/s arrive at once, so a tap moves the body, and the last 4 m/s take two seconds, so a clean line through obstacles is faster than a stop and restart. That is the flow number's point.
- **Licence:** no code or asset is taken; the values are this build's own. Sources as listed in the survey (Wikipedia text CC BY-SA 4.0, quoted for study only; the controllers MIT).

## Measured (2026-11-15, `docs/evidence/movement/round-1/movement-metrics/log.json`)

The movement instrument on the metrics course, at commit `a8290d1`. The simulation is the same on every run of the same build on this machine (the showcase's end-state hash is identical in test mode, in a normal launch and headless), so these are exact, not averages.

| Number | Planned | Measured |
|---|---|---|
| Top speed | 10.0 m/s | 10.00 m/s |
| Rest to run speed (6 m/s) | 0.3 s | 0.225 s (the 1.5 m/s start is given at once) |
| Rest to 70% of top speed | about 0.8 s | 0.65 s |
| Rest to top speed | about 2.3 s, 17 m | 2.15 s, 16.4 m |
| First tick of movement from rest | 12.5 mm | 13.9 mm |
| Jump at full sprint, flat to flat | 6.4 m | 6.417 m (10 m/s for 77 ticks) |
| Jump height | 0.95 m | 0.950 m |
| Jump air time | 0.64 s | 0.642 s |
| Speed kept through a jump and landing | all of it | 100% |
| Standing jump (forward and jump pressed together) | about 1.6 m | 2.22 m |
| Short hop (jump tapped for one tick) | lower than a full jump | 0.41 m |
| Stop from top speed | 0.42 s, 2.1 m | 0.417 s, 2.04 m |
| 90° turn at top speed | no speed lost | lowest speed 9.75 m/s (97.5% kept), on the new heading in 0.325 s |
| Air steering over one full-speed jump | about 30° | 27.8°, 1.56 m sideways, speed unchanged |

Stepped pieces: the largest that succeeds and the first that fails.

| Family | Largest cleared | First failed | How it was run |
|---|---|---|---|
| Gap, jump as the body's center reaches the edge | 6.5 m | 7.0 m | full sprint; the cylinder's rim may overlap either edge |
| Gap, jump on the last tick coyote time allows | 7.5 m | 8.0 m | the most the body can do; not what a route should ask |
| Ledge, jumped onto | 0.9 m | 1.0 m | running jump timed to peak at the face |
| Step, walked up | 0.35 m | 0.4 m | no jump; speed is kept |
| Slope, walked up | 45.0° | 50.0° | no jump |

The 12-riser staircase (0.18 m risers, 0.30 m treads) is climbed at a run with no speed lost. On the moving slab (10 m of travel every 6 s, 5.2 m/s at its fastest) a standing body stays within 4.8 cm of where it stood and a jump at the slab's fastest carries 3.36 m (expected 3.36 m). On the lift, a jump at its fastest (1.7 m/s upward) reaches 1.62 m: the lift's speed is kept.

For `kit`: the gap a route can ask for at a full sprint, with the take-off at the edge, is 6.4 m of air plus whatever overlap the piece allows; grades are worked from `docs/metrics.json`, which is written from this instrument when `traversal` closes.
