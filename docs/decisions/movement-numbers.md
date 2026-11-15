# Decision: movement-numbers

- **Options:**
  1. An athlete's numbers as they are: real gravity (9.8 m/s²), a jump that lifts the body about 0.5 m, five or six seconds to reach top speed. It would look right on a real human model, but nearly a second of hang time and a slow start feel floaty and unresponsive on a screen.
  2. The numbers the exemplar controllers ship with: 12 to 15 m/s, jumps of 2 m and more, speed reached almost at once. Fun in a gray-block arena; on a photographic course with a realistic human they read as a superhero, and a 400 m city is crossed in half a minute.
  3. An athlete's sizes on a game's clock: speeds, heights and distances a trained athlete could show, with time compressed (stronger gravity, quick first acceleration) so the body answers at once.
- **Sources:** `docs/survey/movement-numbers.md` — Wikipedia on footspeed, sprinting, the long jump, the standing long jump, the high jump, the vertical jump and parkour (fetched 2026-11-15); the tuning values in Jeh3no's, DeiranZ's, the NOSHOT and the GDQuest controllers, the Godot platformer demo and `stairs-character`; `BUILD-BRIEF.md` item 1 (route length and time, the flow number).
- **Choice:** option 3. The values live in `MovementTuning` (`game/movement/movement_tuning.gd`); nothing else in the game holds a movement number. They are starting values: measured on the metrics course by the movement instrument, judged by Nick and his son in the `traversal` playtest, and only then fixed into `docs/metrics.json`.

  | Number | Value | Where it sits |
  |---|---|---|
  | Top speed | 10.0 m/s | 80% of the fastest speed ever measured (12.42 m/s) and under the 10.44 m/s the world-record 100 m averaged from a standing start; above NOSHOT's sprint (8) and GDQuest (8), below Jeh3no (12) and DeiranZ (15) |
  | Run speed (reached quickly) | 6.0 m/s | Reached in 0.3 s at 20 m/s² so the first step is immediate; the Godot platformer demo's whole top speed |
  | Build from run to top speed | 2.0 m/s² (2.0 s) | Momentum is worth something: about 2.3 s and 17 m from rest to top speed, against the 60 m a sprinter needs |
  | Brake | 24 m/s² | A stop from top speed in 0.42 s and 2.1 m |
  | Grip (sideways speed shed while turning) | 30 m/s² | A full-speed turn has a 3.3 m radius and loses no speed up to 90° |
  | Sideways and backward speed | 5.1 and 4.2 m/s | 85% and 70% of run speed |
  | Jump height | 0.95 m | Between a standing vertical and what a high jumper's centre of mass gains; under half of Jeh3no's 2.0 m |
  | Time to peak, time to fall | 0.34 s, 0.30 s | Jeh3no's model (0.3 and 0.25 for 2 m); gives gravity of 16.4 m/s² rising and 21.1 m/s² falling, and a take-off speed of 5.59 m/s |
  | Jump at full sprint, flat to flat | 6.4 m by arithmetic (10.0 × 0.64 s) | 72% of the long-jump record (8.95 m); to be confirmed by measurement |
  | Air control | 8 m/s², adds speed only up to 4.0 m/s | Enough to turn a jump about 30° or pull it short; a standing jump reaches about 1.6 m |
  | Short hop | gravity × 2.5 while rising with jump released | The Godot platformer demo cuts the jump on release |
  | Coyote time, jump buffer | 12 and 14 ticks (0.10 s, 0.117 s) | Far under Jeh3no's 0.3 s and NOSHOT's 0.5 s: forgiving, not a second jump |
  | Step height | 0.35 m | `stairs-character` ships 0.33; a stair riser is about half that |
  | Walkable slope | up to 46° | The engine's default is 45° |
  | Fall speed limit | 40 m/s | A third of a metre per tick |
  | Body | cylinder 1.8 m tall, 0.3 m radius, 75 kg | See `player-body` |

- **Reason:**
  - Top speed has to fit the routes. The longest route the brief allows, 2.5 km in five minutes, needs an average of 8.3 m/s. At 10.0 m/s a flowing run (83% of top speed on average) makes that, and the shortest (1.5 km) takes three minutes at the same pace, so every route length in the brief fits its time. At 9 m/s the longest routes could not be run in five minutes; at 12 m/s and up a 1.5 km route is over in about two. It also has to look like a person once `character` puts a realistic human on the body.
  - Jump height and distance are what every obstacle is sized from, so they are kept at what a trained athlete could show: a 6.4 m gap and a 0.95 m ledge are believable in a photograph. Higher ledges and longer reaches are `traversal`'s moves, not a bigger jump.
  - The clock is the game's. Real gravity would hold the body in the air for 0.88 s on a 0.95 m jump; 0.64 s keeps the height and makes the response quick. The exemplars all do this, more strongly.
  - The two-stage acceleration is what makes momentum matter: the first 6 m/s arrive at once, so a tap moves the body, and the last 4 m/s take two seconds, so a clean line through obstacles is faster than a stop and restart. That is the flow number's point.
- **Licence:** no code or asset is taken; the values are this build's own. Sources as listed in the survey (Wikipedia text CC BY-SA 4.0, quoted for study only; the controllers MIT).
