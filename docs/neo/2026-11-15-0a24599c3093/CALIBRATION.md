# Calibration: Neo run 2026-11-15, commit 0a24599 (branch `fable/player-body`)

The Neo result folder beside this file is valid (`HONESTY.json`: AC power, Low Power Mode off, 60 Hz, the display awake for the whole run, 172 samples, zero engine errors in all nine presets). It is the first run that carries the `movement` presets. This file covers those four; the five older presets ran too and their logs are here, but they were not re-run on the laptop at this commit, so they are not compared again.

The laptop numbers are from `docs/evidence/movement/round-1/` at commit `a8290d1`. The one code commit between that and this build changes spelling only. The decision `neo-proxy` predicts a Neo frame from the laptop's GPU time × 2.3. On the Neo GPU time reads 0 (Metal), so it is judged on wall-clock frame time.

## Frame time

| Preset | Laptop GPU p50 | Laptop GPU p95 | Predicted Neo p95 (×2.3) | Neo frame p50 | Neo frame p95 | Neo frame p99 | Neo p50 ÷ laptop GPU p50 | Budget (16.7 / 22 ms) on the Neo |
|---|---|---|---|---|---|---|---|---|
| movement-run-budget (four laptop runs) | 5.57 ms | 6.22 to 7.19 ms | 14.3 to 16.5 ms | 10.4 ms | 11.2 ms | 11.4 ms | 1.87× | met |
| movement-fuzz (saves a frame every 600) | 5.67 ms | 7.72 ms | 17.8 ms | 11.7 ms | 13.5 ms | 15.5 ms | 2.06× | met |

- The frame budget holds on the Neo with a body in the scene: 11.2 ms at p95 and 11.4 ms at p99 against 16.7 and 22.
- The ratio is inside what the first valid run found (1.51× to 2.24×), so this run gives no reason to move the factor of 2.3. That call is the main builder's; `docs/decisions/neo-proxy.md` was not touched.
- The proxy was the noisier of the two machines. One of five laptop runs of `movement-run-budget` failed the proxy limit (GPU p95 8.11 ms, × 2.3 = 18.7 ms) with the same simulation as the four that passed; the Neo's frame times for that run are within a millisecond of each other from p50 to p99.

## Input to motion

Milliseconds, 200 trials each, v-sync on. "Handed to engine" is the stamp taken before `Input.parse_input_event`; the 50 ms budget is judged on it.

| Preset | Machine | Frame | Handed to engine → first motion drawn (p50 / p95 / max) | `_input` → first motion drawn (p50 / p95) | Wait in the engine's buffer (p50 / p95) |
|---|---|---|---|---|---|
| movement-input-motion-key | Neo, 60 Hz | 16.7 | 25.3 / 32.1 / 33.2 | 16.4 / 16.9 | 8.8 / 15.9 |
| movement-input-motion-key | laptop, 120 Hz | 8.4 | 13.5 / 24.5 / 36.3 | 8.3 / 16.7 | 4.6 / 10.9 |
| movement-input-motion-key-60hz | laptop, limiter at 60 fps | 16.7 | 14.6 / 22.8 / 24.4 | 6.5 / 8.2 | 8.2 / 16.0 |
| movement-input-motion-pad | Neo, 60 Hz | 16.7 | 25.1 / 32.5 / 33.5 | 16.5 / 17.0 | 8.4 / 16.1 |
| movement-input-motion-pad | laptop, 120 Hz | 8.5 | 13.2 / 21.8 / 30.2 | 8.2 / 15.5 | 4.4 / 10.5 |
| movement-input-motion-pad-60hz | laptop, limiter at 60 fps | 16.7 | 14.9 / 22.8 / 25.9 | 6.4 / 8.1 | 8.7 / 16.3 |

- The Neo meets the budget: 32.1 ms (key) and 32.5 ms (gamepad) at p95 against 50.
- The Neo's number is what the record `input-latency` worked out from the engine's loop: up to one frame waiting in the buffer, then one frame to draw. Its worst trial is 33.5 ms, two frames.
- Neither laptop row predicts it. The 120 Hz row has frames half as long. The frame-limiter row gets the wait right (8.2 against 8.8 ms at p50) and the draw wrong (6.5 against 16.4 ms), because the limiter sleeps before the loop turns and v-sync blocks after drawing. **For a proxy of the Neo's input to motion, take two 60 Hz frames (33 ms) as the bound, not the limiter's number.**
- The two latency presets show `frame_pass: false` in `bench-summary.json`. That flag means nothing for them: they run with v-sync on, so every frame is 16.7 ms and p95 sits just above the 16.7 ms line by jitter (17.2 ms).

## Fuzz and the run

- `movement-fuzz` on the Neo: 600 s, 72,007 ticks, zero falls through the world, zero stuck states, zero non-finite values, all 14 regions of the course visited.
- It played out on the Neo almost exactly as on the laptop: the same counts of jumps (320), landings (442), pit falls (39) and respawns (60), the same top speeds to 14 digits. It was not bit for bit the same: the highest point reached differs in the eighth digit (3.94829392 m against 3.94829416 m). So ten minutes of simulation drift between the two machines by float rounding, without changing what happened. That is a data point for the `replay` record (brief #7), not a fault.
- `movement-run-budget` (3,447 ticks driven by the input script through the input map) ended in exactly the same state on the Neo as on the laptop: end-state hash `fedc9f5d05f091fd…` in the editor in test mode, in a normal launch, headless, in the exported Linux build and in the exported macOS build on the Neo.
- A tick's scripts cost 0.19 ms on the Neo with one body (`tick_cost_ms` in the log), 0.09 ms in the fuzz run.
