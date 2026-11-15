# Survey: renderer

## Renderers — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/rendering/renderers.rst

> Choose **Forward+** if:
>
>     - You are developing for desktop.
>     - You have relatively new hardware which supports Vulkan, Direct3D 12, or Metal.
>     - You are developing a 3D game.
>     - You want to use the most advanced rendering features.
>
> Choose **Mobile** if:
>
>     - You are developing for newer mobile devices, desktop XR, standalone XR, or
>       desktop.
>     - You have relatively new hardware which supports Vulkan, Direct3D 12, or Metal.
>     - You are developing a 3D game.
>     - You want to use advanced rendering features, subject to the limitations
>       of mobile hardware.

> | Volumetric Fog          | ❌ Not supported.        | ❌ Not supported.        | ✔️ Supported.            |

> | Screen-Space Reflections| ❌ Not supported.        | ❌ Not supported.        | ✔️ Supported.            |

> | Screen-Space Ambient    | ✔️ Supported.            | ❌ Not supported.        | ✔️ Supported.            |
> | Occlusion (SSAO)        |                          |                          |                          |

> | Signed Distance Field   | ❌ Not supported.        | ❌ Not supported.        | ✔️ Supported.            |
> | Global Illumination     |                          |                          |                          |
> | (SDFGI)                 |                          |                          |                          |

## Command line tutorial — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/editor/command_line_tutorial.rst

> | ``--rendering-method <renderer>``        | |release| Renderer name. Valid values are ``forward_plus``, ``mobile``, and ``gl_compatibility``. Requires driver support.                                   |

## Viewport class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Viewport.xml

> Use AMD FidelityFX Super Resolution 2.2 upscaling for the viewport's 3D buffer.

> Use the [url=https://developer.apple.com/documentation/metalfx/mtlfxtemporalscaler#overview]MetalFX temporal upscaler[/url] for the viewport's 3D buffer.

## Performance class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Performance.xml

> The total number of vertices or indices rendered in the last rendered frame. This metric doesn't include primitives from culled objects (either via hiding nodes, frustum culling or occlusion culling). Due to the depth prepass and shadow passes, the number of primitives is always higher than the actual number of vertices in the scene (typically double or triple the original vertex count).

## Local measurement — stress scene, this laptop (Apple M1 Pro, Honeykrisp/Vulkan), 2026-11-15

From `docs/evidence/core/round-1/core-stress-path*/log.json`: 1 km terrain, 40k rocks, 12k alpha-tested plants, 3k trees, 2408×1506, render scale 0.67, 36.2 M primitives per frame.

| Run | Renderer | Profile | GPU p50 | GPU p95 |
|---|---|---|---|---|
| core-stress-path | Forward+ | neo (SSAO, volumetric fog, FSR2) | 25.65 ms | 26.29 ms |
| core-stress-path-mobile | Mobile | neo, features Mobile lacks dropped by the engine | 12.58 ms | 13.08 ms |
| core-stress-path-parity-forward_plus | Forward+ | parity-test (no SSAO, no volumetric fog, no TAA, bilinear) | 16.65 ms | 17.22 ms |
| core-stress-path-parity-mobile | Mobile | parity-test | 12.57 ms | 13.07 ms |
