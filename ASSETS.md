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
