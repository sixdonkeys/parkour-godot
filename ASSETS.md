# Assets and dependencies

Every dependency and asset this game uses or ships, with its source address, author, licence and the licence statement quoted from the source. Third-party files packed into a build live under `game/assets/` or `game/thirdparty/`, and each one must be covered by a `**Path:**` line here; the build step (`tools/verify.py build`) fails any export that packs one that isn't. Everything else in a build is this project's own work.

Credits owed are shown on the in-game credits screen.

## Godot Engine 4.7.2 and its official export templates

- **Path:** (engine and export templates; not files in the repository)
- **Source:** https://github.com/godotengine/godot/releases/tag/4.7.2-stable — templates file `Godot_v4.7.2-stable_export_templates.tpz`, SHA-512 checked against the release's `SHA512-SUMS.txt`.
- **Author:** Juan Linietsky, Ariel Manzur and contributors (Godot Engine contributors)
- **Licence:** MIT (Expat)
- **Licence statement (from https://github.com/godotengine/godot/blob/4.7.2-stable/LICENSE.txt):**
  > Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
  > Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
  >
  > Permission is hereby granted, free of charge, to any person obtaining a copy
  > of this software and associated documentation files (the "Software"), to deal
  > in the Software without restriction, including without limitation the rights
  > to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  > copies of the Software, and to permit persons to whom the Software is
  > furnished to do so, subject to the following conditions:
  >
  > The above copyright notice and this permission notice shall be included in all
  > copies or substantial portions of the Software.
  >
  > THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  > IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  > FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  > AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  > LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  > OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  > SOFTWARE.
- **Changes:** none. The engine's own third-party components (Jolt Physics, MIT, among others) are listed in the engine's `COPYRIGHT.txt`, which the credits screen reproduces.

## Python, numpy and Pillow (verification tools only; never shipped)

- **Path:** (tools only)
- **Source:** Fedora packages `python3`, `python3-numpy`, `python3-pillow`.
- **Licence:** PSF-2.0 (Python), BSD-3-Clause (numpy), MIT-CMU (Pillow).
- Not packed into any build; recorded for completeness.

## USGS 3DEP 1/3 arc-second elevation, tile n33w111 (desert level terrain)

- **Path:** (source data in `tools/cache/usgs/`, not in git; terrain generated from it lives under `game/desert_dress/generated/` and `game/look_slice/generated/`) `look_slice/generated/` `desert_dress/generated/`
- **Source:** https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/13/TIFF/historical/n33w111/USGS_13_n33w111_20261027.tif (metadata `…_20261027.xml` beside it), listed by The National Map API. SHA-256 `bdf3a0751fbc9d31c20b472498d7a6bf87146364b2f8de09787b9be96571505a`.
- **Author:** U.S. Geological Survey, 3D Elevation Program
- **Licence:** public domain
- **Licence statement (from the tile's metadata):**
  > All 3DEP products are public domain.
- **Use constraints (from the same metadata, followed here):**
  > Acknowledgement of the originating agencies would be appreciated in products derived from these data.  Any user who modifies the data is obligated to describe the types of modifications they perform.
- **Changes:** cropped to lon −110.85 to −110.75, lat 32.28 to 32.37 (Sabino Canyon and the Santa Catalina front range); compressed horizontally ×0.1 and vertically ×0.18; resampled to 1 m with seeded fractal detail added; route ground shaped by hand; meshes and rocks placed on top. The game's world is invented, not a map of the real place. Credited to the USGS on the credits screen.

## Poly Haven textures and models (CC0)

- **Path:** `game/assets/polyhaven/` (fetched by `tools/fetch_assets.py`; every file's address and SHA-256 is pinned in `tools/assets.lock.json`)
- **Source:** https://polyhaven.com/ via https://api.polyhaven.com/files/<id> — assets: `cliff_side`, `dry_ground_rocks`, `gravelly_sand`, `namaqualand_boulder_02`, `namaqualand_boulder_03`, `namaqualand_boulder_04`, `namaqualand_boulder_05`, `namaqualand_rocks_01`, `namaqualand_stones_01`, `red_laterite_soil_stones`, `shrub_02`, `wild_rooibos_bush`
- **Author:** Poly Haven and its contributors (each asset's page names its author)
- **Licence:** CC0 1.0
- **Licence statement (from https://polyhaven.com/license):**
  > Our assets are all licensed as CC0 , which is effectively Public Domain even in jurisdictions that do not support the Public Domain.
  > You do not need to give credit or attribution when using them (although it is appreciated).
- **Changes:** none to the files; import settings (VRAM compression, mipmaps) set by `tools/set_imports.py`. Credited on the credits screen anyway.
