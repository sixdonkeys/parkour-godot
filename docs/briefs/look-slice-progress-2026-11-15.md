# look-slice progress (uncommitted scratch while the verify critic runs; fold into docs/NOTES.md after)

## Findings so far (2026-11-15)
- "Ribbons" were the camera underground (ground at (-20,25) is 59.8 m; camera was at 50 m): chunk skirts seen from below. Fix in tracked code (after critic): preset cameras placed relative to ground — add `above_ground` to the verify runner's camera pose (raycast down), and frame views from the height data.
- Terrain GPU 200 ms -> 19.6 ms: Poly Haven textures were imported lossless without mipmaps (only auto-detected 3D use sets VRAM). tools/set_imports.py fixes; fetch_assets runs it.
- Scatter 87 M -> 8.7 M primitives: one MultiMesh spanning 1 km always picks LOD 0; now one MultiMesh per 64 m cell.
- Window fixed to an exact 10.24 km square so roam and backdrop share scale (hole near the ridge gone).

## Dev views (.local/ls-{wide,route,closeup}.json, stills in .local/ls-*/still.png)
GPU p50 about 30 ms on all three (x2.5 proxy about 75 ms vs 6.68 ms budget). About 6 M primitives.

## Look issues, ranked
1. Sky flat grey-blue; needs a deep desert blue (PhysicalSky exposure/rayleigh, physical light units per the lighting record, auto exposure).
2. Saguaros: too dense and too uniform, too smooth and green, arm joints wrong. Need pleat shading, skin texture, realistic spacing (Sonoran: saguaros sparse on bajadas, with palo verde nurse trees), more variation.
3. Shrubs (wild_rooibos_bush, shrub_02) render black. No alpha involved. Suspects: material lost in MultiMesh (override on the MeshInstance, not in the mesh), or the ARM texture. Test by placing one plain MeshInstance from the glTF.
4. Mountains: striped cliff triplanar, too orange; the Catalinas are grey-tan granite/gneiss with green scrub dots.
5. Ground too uniform; needs denser creosote/bursage, gravel, washes.
6. Performance: the main question look-slice answers. Next: break down the cost (shadows, SSAO, scatter, terrain shader, FSR) on these views.
- Black shrubs: the wild_rooibos_bush colour texture is leaves on black (mean RGB about 30); the alpha cut-out isn't in the JPEG variant the fetcher took, and the material blends, so the black shows. shrub_02 renders fine but is a temperate shrub. Both come out of the desert; creosote and bursage need proper sources (search CC0/CC BY Sonoran plant scans, or build procedurally).
- Not SSAO, not MultiMesh, not vertex colour (each tested and ruled out).

## Performance breakdown, route view, GPU p50 on this laptop
- everything on: 31.7 ms (6.4 M primitives, 570 draw calls)
- no scatter: 19.7 ms (scatter costs about 12 ms)
- no sun shadows: 24.1 ms (shadows about 7.6 ms)
- no SSAO, fog or glow: 21.7 ms (post about 10 ms)
- Proxy budget is 6.68 ms GPU (x2.5 factor). The gap is about 5x. Get the Neo's own numbers first (the factor could be wrong either way), then cut: render scale, cheaper terrain shader (one triplanar fetch set, not three), scatter impostors and shorter shadow distance for scatter, SSAO half resolution or off, and alpha-tested foliage cards instead of dense scans.

## verify round 2 to-do (critic round 1, remaining)
- Reference gap mountain/closeup/lowsun: federal libraries not yet searched. Leads: NPGallery album "Landscapes - Sunrises and Sunsets", Wind Cave, 22 items (https://npgallery.nps.gov/SearchResults/albumid/01565430-155D-4519-3E8CAC656F917E9C; page renders by script, so find its JSON endpoint or read item pages); FHWA Byways photo library (https://fhwaapps.fhwa.dot.gov/bywaysp/photos/ — Needles Highway is a byway; check each photo's terms).
- Showcase and test-vs-normal pair on a scene with content (not the blank empty scene): add a new verify preset, never edit the old one.
- Log the graphics driver (dev runs: vulkaninfo driverName/driverInfo for the device used; macOS: Metal plus OS version).
- Docs: neo-proxy says vsync is off (Honeykrisp forces it on), and must justify 2.5x against the 3.3x bandwidth gap or change it; asset-pipeline names tools/build.py (doesn't exist: it's verify.py build); SETUP/README gaps; Neo status wording consistent across WAITING/NOTES/ARCHITECTURE (the Neo is now back).
- Exports ship about 300 MB of Poly Haven textures only look_slice uses: exclude assets/polyhaven/* from game exports until a level uses them.
- Privacy (Nick's call, asked): the son's name in the machine name in docs/targets/neo.json, and the tailnet ID in SETUP.md and neo.json.
