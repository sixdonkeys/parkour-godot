# Survey: quality-profiles

## Viewport class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Viewport.xml

> The automatic LOD bias to use for meshes rendered within the [Viewport] (this is analogous to [member ReflectionProbe.mesh_lod_threshold]). Higher values will use less detailed versions of meshes that have LOD variations generated. If set to [code]0.0[/code], automatic LOD is disabled. Increase [member mesh_lod_threshold] to improve performance at the cost of geometry detail.

> The multisample antialiasing mode for 3D rendering. A higher number results in smoother edges at the cost of significantly worse performance.

> Scales the 3D render buffer based on the viewport size uses an image filter specified in [member ProjectSettings.rendering/scaling_3d/mode] to scale the output image to the full viewport size. Values lower than [code]1.0[/code] can be used to speed up 3D rendering at the cost of quality (undersampling).

> Use the [url=https://developer.apple.com/documentation/metalfx/mtlfxtemporalscaler#overview]MetalFX temporal upscaler[/url] for the viewport's 3D buffer.

> Use AMD FidelityFX Super Resolution 2.2 upscaling for the viewport's 3D buffer. The amount of scaling can be set using [member Viewport.scaling_3d_scale]. Values less than [code]1.0[/code] will result in the viewport being upscaled using FSR2.

> The shadow atlas' resolution (used for omni and spot lights). The value is rounded up to the nearest power of 2.

> Enables temporal antialiasing for this viewport. TAA works by jittering the camera and accumulating the images of the last rendered frames, motion vector rendering is used to account for camera and object motion.

## RenderingServer class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/RenderingServer.xml

Runtime setters for global quality (method names quoted from the reference):

> <method name="directional_shadow_atlas_set_size">

> <method name="directional_soft_shadow_filter_set_quality">

> <method name="positional_soft_shadow_filter_set_quality">

> <method name="environment_set_ssao_quality">

> <method name="environment_set_sdfgi_ray_count">

> <method name="gi_set_use_half_resolution">

> <method name="environment_set_volumetric_fog_volume_size">

## ProjectSettings class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml

> [b]Note:[/b] This setting is an override. The texture importer will always import the format the host platform needs, even if this is set to [code]false[/code].

## Build brief, item 1

> Every setting that trades looks for speed (render scale, lighting method, shadows, texture and mesh detail, effects) lives in a quality profile, one file per profile; the game ships one profile, `neo`; source art is kept at the best quality obtained and reduced per profile.
