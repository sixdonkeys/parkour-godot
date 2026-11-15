# Decision: quality-profiles

- **Options:**
  1. Project-setting overrides per feature tag (e.g. `rendering/...` with a `.neo` suffix), chosen by the export's custom feature. These are read only at start-up, they can't hold texture tiers, and a new tier means editing `project.godot`.
  2. One `QualityProfile` resource file per profile in `game/profiles/`, applied at runtime to the viewport, the RenderingServer globals, and each level's environment and lights as it loads. Textures come in tiers made at build time.
  3. Levels authored once per tier (separate scenes per profile). Rejected: a new tier would be a rework of every level, which the brief forbids.
- **Sources:** `docs/survey/quality-profiles.md` — Viewport, RenderingServer and ProjectSettings class reference 4.7.2; the brief.
- **Choice:** option 2.
  - **`QualityProfile` (`game/core/quality_profile.gd`, a `Resource`)** holds every setting that trades looks for speed:
    - Render scale and upscaler, as an ordered preference list. The first one the running driver supports is used: MetalFX temporal on Metal, FSR2 elsewhere, then bilinear.
    - Anti-aliasing: MSAA, TAA, screen-space AA.
    - Mesh LOD threshold.
    - Shadows: directional atlas size, split count, max distance, soft-shadow quality; positional atlas size.
    - Effect caps: SDFGI on/off and ray count, SSAO quality, SSIL, SSR and its steps, volumetric fog and its volume size, glow, half-resolution GI.
    - Texture tier: the folder suffix the asset resolver uses.
    - Scatter density and draw-distance multipliers, read by levels when they place instances.
  - **Applying it:** `apply(viewport, scene)` sets the viewport and RenderingServer values, then walks the loaded scene. Every `WorldEnvironment` has its effects clamped to the profile's caps. Every `DirectionalLight3D` gets the profile's shadow settings. Every node in group `quality_scaled` is asked to `apply_quality(profile)`. `describe()` returns the settings for the log.
  - **Levels are authored at the highest quality they are meant to have.** The profile only clamps down. So a better tier later is a new `.tres` file with higher caps, and nothing in a level or in code changes.
  - **Textures:** source art stays at full resolution (`asset-pipeline`). A build-time tool writes reduced copies per tier under `game/assets/_tiers/<tier>/`, mirroring the source paths. Materials load textures through `Assets.texture(path)`, which returns the active tier's copy when one exists, else the source.
  - **Shipping:** the game ships one profile, `neo.tres`. A throwaway second profile (`game/profiles/throwaway-low.tres`) exists only for the preset that proves a tier is just a new file. It is excluded from exports.
  - A missing or broken profile falls back to built-in `neo` defaults and logs the error (ARCHITECTURE.md, Failure isolation).
  - **Upscaler costs measured here** (empty scene, 2408×1506, render scale 0.67, GPU p50; `docs/evidence/core/round-1/core-upscaler-*`): bilinear without TAA 0.88 ms; bilinear with TAA 4.05 ms; FSR1 with TAA 4.92 ms; FSR2 8.64 ms.
    - FSR2 alone would take half the proxy GPU budget (6.68 ms), so the neo profile's fallback on Vulkan is FSR1 with TAA. Its first choice on the Neo stays MetalFX temporal; its cost there is unmeasured and is settled by the Neo's first `bench`.
    - Without TAA: FSR1 with SMAA 4.31 ms; FSR1 with FXAA 3.93 ms; native scale with SMAA 2.59 ms.
    - So `neo` now uses SMAA, not TAA, with non-temporal upscalers (TAA alone cost about 3.2 ms here). Screen-space AA is switched off whenever a temporal upscaler is chosen, since it anti-aliases by itself.
    - The final scale and upscaler are chosen on real content in `look-slice`, then corrected by the Neo's numbers.
    - The list is data in `neo.tres`, so this choice moves without code changes.
- **Reason:** only option 2 makes a new tier cost one file. Everything it touches can be changed at runtime through documented APIs, so the same level scene serves every tier. The upscaler preference list lets the Neo use Apple's own temporal upscaler, the largest single saving on its GPU, without tying the code to macOS.
- **Licence:** Godot engine, MIT. MetalFX is part of macOS and reached through the engine; FSR2 ships inside the engine (MIT).
