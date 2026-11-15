# Decision: landforms

- **Options (terrain engine):**
  1. Terrain3D (MIT, GDExtension, clipmap terrain with texture painting and instancing): proven and fast. But it ships no Linux arm64 library, which this development laptop needs, so using it means building it from source on every arm64 machine, with a C++ toolchain and a compile step the brief's script-only stack avoids.
  2. Our own GDScript generator, run at build time: heightfields cut into chunk meshes with generated LODs, `HeightMapShape3D` collision built from the same heights, and a splatting shader. The world is fixed at build time anyway, so nothing runtime-adaptive is needed.
- **Options (source data):** USGS 3DEP 1/3 arc-second (about 10 m) seamless DEM, or 3DEP 1 m lidar DEMs. At the 10× horizontal compression the brief requires, 10 m data already gives about 1 m effective spacing; 1 m lidar is kept for the cliffs and outcrop pieces, if needed.
- **Sources:** `docs/survey/landforms.md` — USGS 3DEP tile metadata (public domain statement and use constraints, quoted); The National Map API listing; Terrain3D release contents; the brief; local measurements of the Sabino Canyon window.
- **Choice:** option 2 on 3DEP 1/3 arc-second data.
  - **Desert source:** tile `n33w111`, published 2026-10-27, SHA-256 `bdf3a075…505a`, fetched by `tools/fetch_assets.py` into `tools/cache/usgs/` (not in git). Window: lon −110.85 to −110.75, lat 32.28 to 32.37, about 9.4 × 10 km. It runs from the desert floor below Sabino Canyon (771 m) through the canyon into the Santa Catalina front range (2138 m).
  - **Compression:** horizontal 10 km → 1 km (×0.1); vertical 1367 m → about 250 m (×0.18), inside the brief's 150–300 m. Slopes come out about 1.8× steeper than the real ones.
  - **Detail beyond the data:** bicubic resampling to 1 m, plus seeded fractal detail weighted by slope (rock on steep ground, small dunes and washes on flat) at under 1 m amplitude. The route's own ground is shaped by hand on top.
  - **What a height map can't hold** (cliff faces, overhangs, the Javelina-Rocks-style outcrop): meshes placed on top: CC0 scanned rock assets where the policy allows, assembled into formations, with trimesh collision.
  - **Scatter:** a seeded rule set per level by slope, height, aspect and distance from washes. Desert: saguaro, palo verde, prickly pear, ocotillo, creosote, brittlebush, boulders, gravel. Higher up, scrub oak and grass. Each kind is a `MultiMeshInstance3D` per terrain chunk, with density scaled by the profile and visibility ranges set.
  - **Backdrop:** the same tile at lower resolution beyond the roamable square, compressed the same way and merged into far meshes, out to the horizon. Visible, never reachable (blocked by a soft boundary).
  - **Storage, so the world can be made again:**
    - In git: the generator (`tools/gen/`), its seed, and the tile's address and checksum in `ASSETS.md` and `tools/assets.json`.
    - Not in git, if large: the generated chunk meshes and collision under `game/<env>_dress/generated/`, rebuilt by the build step.
    - Generation is deterministic: same tile, same seed, same chunks on every machine.
  - **Collision true to what's seen:** collision is built from the same heights as the visible mesh at the highest LOD (1 m). LOD only removes detail far from any body, and the route's ground is checked by the instruments.
  - **The cities:** the lidar and building-record sources are chosen when `chicago-course` and `newyork-course` start; that part of this record is "undecided — chicago-course".
- **Reason:** option 2 keeps the stack script-only, with no compile step, as the brief wants. It runs on every target including this arm64 laptop, and a build-time world needs none of Terrain3D's runtime editing. 10 m public-domain data is all the shape a 1 km compressed world can show.
- **Licence:** USGS 3DEP is public domain (quoted). Credit to the USGS is shown on the credits screen, and the changes (crop, compression, added detail) are described in `ASSETS.md`, as the data's use constraints ask. The generator is our own code.
