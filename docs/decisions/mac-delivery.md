# Decision: mac-delivery

- **Options:**
  1. Export from Linux with Godot's built-in ad-hoc signing, notarization disabled, packaged as a `.zip` of the `.app`.
  2. Sign and notarize with `rcodesign` and an Apple Developer ID. Needs a paid developer account, which this build doesn't have and may not create.
  3. Export unsigned and have the receiving Mac ad-hoc sign it with `codesign`. Needs the command-line tools there.
- **Sources:** `docs/survey/mac-delivery.md` — godot-docs `exporting_for_macos.rst` and `running_on_macos.rst`.
- **Choice:** option 1. The macOS preset is a universal binary, code signing "Built-in (ad-hoc only)", notarization disabled, exported to `.zip`. Zipping keeps the executable flag and the bundle intact on the way. Both VRAM compression families are imported, so one pack serves Apple GPUs.
  - **A build handed over as a file:** after unzipping, the person right-clicks (Control-clicks) the app and chooses Open, once. If macOS still refuses, they run `xattr -dr com.apple.quarantine Ridgeline.app`. Both steps go into README.md.
  - **A build copied by the remote loop (when the Neo returns):** `scp`/`rsync` from a shell doesn't set the quarantine attribute the way a browser download does. So a copied build should start once it's unzipped there, subject to `remote-test`'s own check.
- **Reason:** option 1 is the only route with no paid account and nothing installed on the receiving Mac, and it is what Godot's own docs advise without a certificate. Option 2 stays open if Nick ever gets a developer ID; the preset just changes its signing option.
- **Licence:** Godot engine and its official export templates, MIT.
