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

Formats:
- **Camera path** (`paths/*.json`, `camera-path/1`): `{id, duration_s, far, keys: [{t, pos: [x,y,z], look_at: [x,y,z], fov}]}`. Positions are interpolated with cubic (Catmull-Rom style) curves; in test mode time advances 1/60 s per frame.
