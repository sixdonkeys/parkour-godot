# Decision: renderer

- **Options:**
  1. Forward+: every feature (SSAO, SSIL, SSR, volumetric fog, SDFGI and VoxelGI, FSR2), at the highest cost per frame.
  2. Mobile: built for tile-based GPUs like the A18 Pro's. Cheaper per frame, but no SSAO, SSR, SSIL, volumetric fog, SDFGI or FSR2.
  3. Compatibility (OpenGL): the widest hardware reach, and the fewest features. Rejected: it can't approach the photographic bar.
- **Sources:** `docs/survey/renderer.md` — godot-docs `renderers.rst` (choice guidance and feature tables); command line tutorial (`--rendering-method`); Viewport and Performance class reference 4.7.2; local stress-scene measurements of both renderers.
- **Choice:** Forward+, with Mobile kept measured as the fallback.
  - **Measured on this laptop** (proxy), on the stress scene at the Neo's resolution:
    - With features matched (no SSAO, no volumetric fog, no TAA, bilinear scaling), Mobile's GPU time is 12.6 ms against Forward+'s 16.6 ms, 24% less.
    - With the neo profile's effects, Forward+ takes 25.6 ms. SSAO, volumetric fog and FSR2 together cost about 9 ms on this scene.
    - Both are far over the proxy GPU budget of 6.68 ms. The stress scene is deliberately heavy: 36 M primitives, no LOD, every instance casting shadows.
  - **Reopening trigger:** if `look-slice` can't meet the frame budget on Forward+ with the neo profile at a score the critic accepts, this record is reopened and Mobile is measured on the same slice. Benchmarks keep running both (`--rendering-method mobile`) so the comparison is always fresh.
  - **Budgets on the neo profile** (starting values, calibrated in `look-slice`, then by the Neo):
    - GPU time: the proxy rule in `neo-proxy`, GPU × 2.5 within the frame budget.
    - At most **8 M primitives per frame**, including depth prepass and shadow passes (the Performance monitor counts both), and at most **2,500 draw calls per frame**.
  - **How the budgets are met:**
    - Instancing: scatter (rock, plant, tree, roof clutter) is drawn with `MultiMeshInstance3D`, one per mesh per terrain tile.
    - Level of detail: the engine's automatic mesh LOD, generated on import, plus visibility ranges with fade on every scattered and backdrop mesh. Distant backdrop is merged into impostor meshes made at build time.
    - Culling: frustum culling everywhere, with occluders baked for the two city levels (`OccluderInstance3D`).
    - Shadows only from objects near enough to matter: casting turned off past a distance per kind, and the profile's shadow distance.
- **Reason:** the photographic bar, and Nick's AAA goal, need ambient occlusion, volumetric atmosphere, reflections and temporal upscaling, which only Forward+ has. On the Neo, MetalFX temporal upscaling lets it render at about two-thirds resolution. The 24% saving Mobile gives at matched features is real, but smaller than what render scale, LOD and shadow distance give on Forward+. Mobile stays measured, so the choice can be reversed on evidence rather than argued.
- **Licence:** Godot engine, MIT. FSR2 is bundled with the engine (MIT). MetalFX is part of macOS.
