# Build notes

One entry per round: what was tried, what failed, why. Read this first when resuming.

## 2026-11-15 — start (stage 1)

- Folder was empty apart from `BUILD-BRIEF.md`; the dotfiles visible inside the sandbox are its placeholders (character devices), not real files, so they are excluded locally in `.git/info/exclude`.
- Machine: MacBook Pro 16" M1 Pro, Fedora Asahi 44, live session GNOME (Wayland). The sandbox has no `/dev/dri`; everything that draws runs outside it.
- Godot 4.7.2 (Fedora build `4.7.2.stable.fedora.ed1daf0bf`). Official export templates 4.7.2-stable downloaded (SHA-512 checked) into `.local/data/godot/export_templates/4.7.2.stable`.
