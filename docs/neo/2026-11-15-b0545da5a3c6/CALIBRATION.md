# Calibration: Neo run 2026-11-15, commit b0545da

The Neo result folder beside this file (`HONESTY.json`: valid; AC power, Low Power Mode off, 60 Hz, the game in front for the whole run) is set against the same presets run on the Fedora laptop at the same code (`docs/evidence/*/round-2/<preset>-calib/`). The decision `neo-proxy` predicts a Neo frame from the laptop's GPU time × 2.5.

| Preset | Laptop GPU p50 | Laptop GPU p95 | Predicted Neo p95 (×2.5) | Neo frame p50 | Neo frame p95 | Neo p50 ÷ laptop GPU p50 |
|---|---|---|---|---|---|---|
| core-empty-neo | 4.34 ms | 6.17 ms | 15.4 ms | 7.97 ms | 8.97 ms | 1.84× |
| core-stress-path | 18.93 ms | 19.51 ms | 48.8 ms | 42.32 ms | 43.14 ms | 2.24× |
| verify-showcase | 5.14 ms | 6.03 ms | 15.1 ms | 9.61 ms | 9.93 ms | 1.87× |
| verify-empty-still | 4.34 ms | 5.79 ms | 14.5 ms | 6.55 ms | 6.80 ms | 1.51× |
| verify-empty-path | 3.60 ms | 5.66 ms | 14.2 ms | 6.54 ms | 7.06 ms | 1.82× |

**What this shows.**
- The prediction was cautious on every preset: the Neo did better than ×2.5 forecast.
- The ratio runs 1.51–1.87× on the light scenes and 2.24× on the heavy stress scene. The heavy scene is GPU-bound on both machines, and real levels will be heavy, so it is the ratio that matters.
- The two machines use different upscalers: FSR1 on the laptop, MetalFX temporal on the Neo. The ratio includes that difference, and this profile will ship with it.

**Correction to `neo-proxy`:** the factor goes from 2.5 to **2.3**. That is just above the largest measured ratio (2.24), so the proxy is still never more lenient than the Neo. One valid run is a small sample: every later valid Neo run is added here, and the factor follows the largest ratio seen on GPU-bound presets.

**Instrument notes from the Neo (Metal):**
- GPU time reads 0, so Neo results are judged on wall-clock frame time.
- Texture-memory readings are unreliable there. The Fable planning agent reported a 64-bit maximum value, and process memory falling after a load.
- So the memory budget is judged from the laptop until the Neo's memory readings are fixed. That is an open issue on `verify`.
