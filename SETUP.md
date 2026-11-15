# Setup

What a machine needs before this project builds and verifies on it. A fresh clone plus this file is enough; nothing else the build needs lives outside the repository.

**Check a machine** (from the project folder):

```
python3 tools/verify.py setup-check
```

It prints `all present`, or what's missing.

## Tools

| Tool | Version | Why |
|---|---|---|
| Godot | **4.7.2** exactly (`4.7.2.stable`) | Engine and editor; same version on every machine |
| Godot export templates | 4.7.2-stable | Exporting builds; kept inside the project in `.local/` |
| git | any recent | Version control |
| curl, unzip | any | Fetching templates and source data |
| Python | 3.11 or later | Verification tool (`tools/`) |
| numpy, Pillow | any recent | Image and sound numbers in the verification tool |
| eu-stack (elfutils) | any | Optional: thread stacks when diagnosing a hang (Linux) |
| ssh, rsync | any | The remote loop to test machines |
| niri, Umbriel | any | Window tests nested in a window (Fedora laptop only; optional elsewhere) |
| tifffile, imagecodecs | pinned in `tools/requirements.txt` | Reading USGS elevation tiles (terrain generator) |

The terrain generator's Python packages go in a project-local virtual environment, never system-wide:

```
python3 -m venv .local/venv --system-site-packages
.local/venv/bin/pip install -r tools/requirements.txt
```

### Fedora Asahi Linux (aarch64)

```
sudo dnf install godot git curl unzip python3-numpy python3-pillow elfutils
```

Fedora 44 ships `godot-4.7.2-1.fc44`; check with `godot --version` (`4.7.2.stable.fedora…`). If Fedora moves to a newer Godot, use the official 4.7.2 build instead (see "Godot 4.7.2 from the official release" below).

### CachyOS (x86_64)

```
sudo pacman -S git curl unzip python-numpy python-pillow elfutils
```

Then Godot 4.7.2 from the official release (below). CachyOS's `godot` package follows the newest version.

### macOS (Apple silicon)

```
xcode-select --install
brew install python numpy pillow
```

Then Godot 4.7.2 from the official release (below). Don't use `brew install godot`; it installs the newest version.

### Godot 4.7.2 from the official release

From https://github.com/godotengine/godot/releases/tag/4.7.2-stable, check the file against `SHA512-SUMS.txt` from the same release:
- Linux x86_64: `Godot_v4.7.2-stable_linux.x86_64.zip`
- Linux arm64: `Godot_v4.7.2-stable_linux.arm64.zip`
- macOS: `Godot_v4.7.2-stable_macos.universal.zip` (move `Godot.app` to `/Applications`)

Unzip it and point the tools at it with `export GODOT=/path/to/godot` if it isn't on `PATH` as `godot`.

### Export templates (every machine, once)

The templates live inside the project (`.local/data/godot/export_templates/4.7.2.stable/`, git-ignored), because the tools run the engine with its settings, caches and data folders pointed into `.local/`. From the project folder:

```
mkdir -p .local/downloads && cd .local/downloads
curl -LO https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt
curl -LO https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
grep export_templates.tpz SHA512-SUMS.txt | grep -v mono | sha512sum -c
mkdir -p ../data/godot/export_templates && cd ../data/godot/export_templates
unzip -q ../../../downloads/Godot_v4.7.2-stable_export_templates.tpz
mv templates 4.7.2.stable
```

(On macOS use `shasum -a 512 -c` in place of `sha512sum -c`.)

## Notes for the Fedora laptop

- The Claude Code sandbox hides the graphics chip (`/dev/dri` is absent inside it), so everything that draws (`tools/verify.py run`, `prove`, `window`) runs outside it. Exports (`build`) work inside it.
- Window tests use niri and Umbriel nested in a window, with throwaway configs in `tools/wm/`; both are already installed on this laptop. Nick's own configs are never read or changed.

## Test machines (the remote loop)

The Neo is tested remotely over Tailscale and SSH: `python3 tools/verify.py remote neo check` (also `send`, `bench`, `play`, `fetch`). Nothing is installed on the Neo for this beyond Tailscale and Remote Login.

One-time setup (Nick):
1. On the Neo: Tailscale signed in; System Settings → General → Sharing → Remote Login on, for the account logged in at the screen; each development machine's public key in that account's `~/.ssh/authorized_keys`; a folder `~/RidgelineTest`. Plugged in, Low Power Mode off, and the display kept awake (Amphetamine, or a long display-sleep time) for honest runs.
2. On each development machine, open `~/.ssh/config` in an editor and add an entry named `neo`:
   ```
   Host neo
       HostName <the Neo's full Tailscale name, ending .ts.net>
       User <the son's macOS username>
   ```
3. Check from the project folder: `python3 tools/verify.py remote neo check`. It should print the Neo's state as JSON, not an error line.

The ThinkPad T14 is added the same way later: a `docs/targets/t14.json` and a `t14` entry in `~/.ssh/config`.
