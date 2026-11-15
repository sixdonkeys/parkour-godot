# Decision: lighting

- **Options:**
  1. Fully real-time: sun with cascaded shadows, sky, SDFGI for bounce light, SSAO and SSR.
  2. Hybrid: a real-time sun and sky for direct light and shadows, with indirect light baked at build time (LightmapGI on the hand-built set pieces and city blocks; a baked sky-occlusion and bounce term in terrain vertex colour or texture for the large terrain), plus SSAO for contact shadows and cheap height fog with a small volumetric-fog budget for depth.
  3. Fully baked, with no time-of-day change. Rejected: the presets need two times of day per level, and a fixed bake would double every bake.
- **Sources:** `docs/survey/lighting.md` — godot-docs introduction to global illumination (performance ranking); physical light and camera units; renderers feature table; local stress-scene measurements.
- **Choice:** option 2, tuned for the photographic bar inside the neo budget.
  - **Materials:** physically based throughout (`StandardMaterial3D` or shaders with albedo, normal, roughness and AO from scanned CC0 sets). Albedo is kept within real-world ranges, checked on the look-slice stills against the reference photos.
  - **Sun and sky:** `DirectionalLight3D` with physical light units on (`rendering/lights_and_shadows/use_physical_light_units`). Sun intensity, colour temperature and direction come from the time of day and the place's latitude: Tucson 32.3° N, the Black Hills 43.9° N, Chicago 41.9° N, New York 40.7° N. The sky is `PhysicalSkyMaterial` with turbidity per level, and auto-exposure keeps the low-sun presets right.
  - **Shadows:** two cascades out to the profile's shadow distance (150 m on neo), PCF soft shadows. Distant terrain self-shadowing comes from the baked sky-occlusion term, so long-range shadow cascades aren't needed.
  - **Indirect light:** baked at build time.
    - Terrain: a sky-visibility (ambient occlusion) term computed from the heightfield by the landforms generator, stored as a texture and multiplied into ambient light.
    - Set pieces and city blocks: LightmapGI, indirect only, so the sun stays real-time for both times of day. Two bakes per level if one bake can't serve both suns; checked in look-slice.
    - SDFGI is not used on neo (it's capped off in the profile) but kept for a later better tier.
  - **Atmosphere:** exponential height fog with the sun's scattering colour on every level. Volumetric fog only within the profile's cap, for canyon depth and city haze at low sun. The reference rules ask for no heavy haze, so it is subtle.
  - **Tonemapping:** AgX, with exposure from physical camera units on the gameplay camera and auto-exposure clamped to a narrow range.
- **Reason:** measured on the stress scene, real-time GI and screen-space effects cost far more than the neo GPU budget allows. Baking the indirect light keeps its look at almost no runtime cost. The sun stays real-time because both times of day, and photo mode, need it.
- **Licence:** Godot engine, MIT. No third-party lighting code.
