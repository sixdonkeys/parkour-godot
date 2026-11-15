# Survey: lighting

## Introduction to global illumination — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/3d/global_illumination/introduction_to_global_illumination.rst

> In order of performance from fastest to slowest:

> - **LightmapGI:**
>
>   - Lights can be baked with indirect lighting only, or fully baked on a
>     per-light basis to further improve performance. Hybrid setups can be used
>     (such as having a real-time directional light and fully baked positional lights).

> - **SDFGI:**
>
>   - The number of cascades can be adjusted to balance performance and quality.
>     The number of rays thrown per frame can be adjusted in the Project Settings.
>     The rendering can optionally be performed at half resolution
>     (and then linearly scaled) to improve performance significantly.
>     **Not available** *when using the Mobile or Compatibility renderers.*

> SSAO has a significant performance cost, so make sure to disable

> SSR has a significant performance cost (even more so than SSAO), so make sure to disable

## Physical light and camera units — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/3d/physical_light_and_camera_units.rst

> other 3D software that uses physical light units (such as Blender).

> The biggest disadvantage of using physical light units is you will have to pay

> In practice, this means that you will have to manually manage your exposure

## Renderers — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/rendering/renderers.rst

> | Volumetric Fog          | ❌ Not supported.        | ❌ Not supported.        | ✔️ Supported.            |

## Local measurement — stress scene (docs/evidence/core/round-1/)

SSAO, volumetric fog and FSR2 together cost about 9 ms of GPU on the stress scene (Forward+ neo 25.65 ms against parity 16.65 ms), and the throwaway profile with SDFGI, SSR and SSIL at full scale took 25.31 ms against neo's 20.16 ms on the same pose.
