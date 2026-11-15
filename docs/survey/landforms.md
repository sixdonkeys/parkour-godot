# Survey: landforms

## USGS 3DEP 1/3 arc-second tile n33w111 (2026-10-27) — metadata https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/13/TIFF/historical/n33w111/USGS_13_n33w111_20261027.xml

> Seamless 3DEP data are available nationally (except for Alaska) at resolutions of 1 arc-second (approximately 30 meters) and 1/3 arc-second (approximately 10 meters).

> All elevation values are in meters and, over the conterminous United States, are referenced to the North American Vertical Datum of 1988 (NAVD 88).

> All 3DEP products are public domain.

> Acknowledgement of the originating agencies would be appreciated in products derived from these data.  Any user who modifies the data is obligated to describe the types of modifications they perform.

## USGS The National Map API — https://tnmaccess.nationalmap.gov/api/v1/products?datasets=National%20Elevation%20Dataset%20(NED)%201/3%20arc-second&bbox=-110.95,32.25,-110.70,32.47&prodFormats=GeoTIFF

Returned (title | publication date | size | address), latest used:
> USGS 1/3 Arc Second n33w111 20261027 | 2026-10-27 | 443259865 | https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/13/TIFF/historical/n33w111/USGS_13_n33w111_20261027.tif

SHA-256 of the file fetched 2026-11-15: `bdf3a0751fbc9d31c20b472498d7a6bf87146364b2f8de09787b9be96571505a`.

## Terrain3D — https://github.com/TokisanGames/Terrain3D (MIT, release v1.1.0-stable, 2026-10-30)

From the release's `addons/terrain_3d/terrain.gdextension`:
> linux.debug.x86_64 = "res://addons/terrain_3d/bin/libterrain.linux.debug.x86_64.so"
> linux.release.x86_64 = "res://addons/terrain_3d/bin/libterrain.linux.release.x86_64.so"

> #linux.debug.arm64 = "res://addons/terrain_3d/bin/libterrain.linux.debug.arm64.so"
> #linux.release.arm64 = "res://addons/terrain_3d/bin/libterrain.linux.release.arm64.so"

(The Linux arm64 entries are commented out, and the release zip carries no Linux arm64 library.)

## Build brief, items 1 and Rules

> The editor runs natively on every development machine, and a script-only project needs no compile step per platform.

> a native plugin only if it supplies or builds for macOS arm64, Linux arm64 and Linux x86_64 and does not rule out Windows x86_64

## Local measurement — the Sabino Canyon window (lon −110.85 to −110.75, lat 32.28 to 32.37)

From the tile above: 972 × 1080 samples, elevation 771–2138 m, 5th percentile 799 m, 95th 1687 m.
