# Survey: asset-pipeline

## Importing images — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/assets_pipeline/importing_images.rst

> - **VRAM Compressed:** This is the default and most common compression mode for

> | **Description**  | Stored as Lossless WebP / PNG | Stored as Lossy WebP | Stored as S3TC, BPTC or ETC2 depending on platform   | Stored as raw pixels   | Transcoded to VRAM Compressed format |

> If enabled, uses BPTC compression on desktop platforms and :abbr:`ASTC (Adaptive
> Scalable Texture Compression)` compression on mobile platforms. When using BPTC,

## ProjectSettings class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml

> If [code]true[/code], the texture importer will import VRAM-compressed textures using the Ericsson Texture Compression 2 algorithm for lower quality textures and normal maps and Adaptable Scalable Texture Compression algorithm for high quality textures (in 4×4 block size).

> If [code]true[/code], the texture importer will import VRAM-compressed textures using the S3 Texture Compression algorithm (DXT1-5) for lower quality textures and the BPTC algorithm (BC6H and BC7) for high quality textures. This algorithm is only supported on PC desktop platforms and consoles.

## Godot pack reader source (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/io/file_access_pack.cpp

> 	uint32_t version = f->get_32();
> 	uint32_t ver_major = f->get_32();
> 	uint32_t ver_minor = f->get_32();
> 	uint32_t ver_patch = f->get_32(); // Not used for validation.

> 		uint64_t dir_offset = f->get_64() + pck_start_pos;

> 		uint32_t sl = f->get_32();

> 		uint64_t ofs = f->get_64();
> 		uint64_t size = f->get_64();
> 		uint8_t md5[16];
> 		f->get_buffer(md5, 16);
> 		uint32_t flags = f->get_32();

## Build brief, item 1 (`BUILD-BRIEF.md`)

> GitHub refuses any file over 100 MB and Git LFS is not installed on the Fedora laptop, so one option is to keep large source art out of git and fetch it again from the addresses in `ASSETS.md`, checked against recorded checksums.

## Local probe — `vulkaninfo`, Apple M1 Pro under Honeykrisp (Mesa 26.2.6), 2026-11-15

> 	textureCompressionETC2                  = true
> 	textureCompressionASTC_LDR              = true
> 	textureCompressionBC                    = true
