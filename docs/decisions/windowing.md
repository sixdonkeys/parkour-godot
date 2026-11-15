# Decision: windowing

- **Options:**
  1. Stretch mode `disabled`: 3D at the window's size, interface laid out at 1:1 pixels and scaled by hand from the window's size.
  2. Stretch mode `canvas_items` with aspect `expand`: 3D renders at the window's own size (times the profile's render scale), and the interface scales from a base size, gaining room on whichever axis the window has extra.
  3. Stretch mode `viewport`: everything renders at a fixed base size and is scaled, which blurs at any other window size. Kept only for capture in test mode (see `verification-rendering`).
- **Sources:** `docs/survey/windowing.md` — Godot 4.7.2 Wayland display server source (app ID); ProjectSettings, DisplayServer and Window class reference 4.7.2; local `niri --help`, `umbriel --help`.
- **Choice:** option 2. Base size 1280×800, `display/window/stretch/mode = "canvas_items"`, `aspect = "expand"`. On top of that, a `core` script recomputes `content_scale_factor` from the window's smaller side, so the interface stays readable in a narrow column and doesn't balloon in a wide strip.
  - **Identity:** `application/config/name = "Ridgeline"`. Godot uses it as the Wayland app ID, so the app ID and title are both `Ridgeline`. One window: `embed_subwindows = true`, boot splash image off, no extra windows.
  - **Size:** the project sets no window size, position or mode at start-up. It takes whatever the window manager gives and reacts to `size_changed`.
  - **Fullscreen:** a toggle between `WINDOW_MODE_FULLSCREEN` (not exclusive) and `WINDOW_MODE_WINDOWED`, on F11 and in the settings menu. Going back to windowed lets the window manager restore the tile.
  - **Pointer:** `MOUSE_MODE_CAPTURED` only while a run is in play and the window has focus. Pause, any menu, `NOTIFICATION_APPLICATION_FOCUS_OUT` or `NOTIFICATION_WM_WINDOW_FOCUS_OUT` set `MOUSE_MODE_VISIBLE` in the same frame. A focus loss also pauses the run.
  - **Keys:** nothing is bound to Meta/Super, and the keyboard is never grabbed (no shortcut-inhibit requests).
  - **Display scaling:** `display/window/dpi/allow_hidpi = true`. The interface scale reads `DisplayServer.screen_get_scale()`.
  - **Decorations:** left to the window manager. Server-side where offered; Godot draws its own (libdecor) where not.
  - **Window tests:** one sequence per window manager, logged by name.
    - GNOME (the live session): the test harness, standing in for the window manager, resizes through `DisplayServer.window_set_size`. This is only possible for a floating window and only in test mode; it is labelled as harness-driven.
    - Niri: run nested in a window, `niri -c <test config> -- <game>`, driven by `niri msg action` (column widths, fullscreen, focusing a second client to take focus away).
    - Umbriel: the same way if it can run nested. Otherwise a playtest check for Nick, through `docs/WAITING.md`.
- **Reason:** option 2 is the only one where the 3D picture is always drawn at the window's real size, so nothing is stretched or blurred, and where the interface follows any shape. It is Godot's recommended mode for non-pixel-art games and the default for 4.7 projects. App ID from the project name is the engine's own mechanism, so window rules can match it with no code of ours.
- **Licence:** Godot engine, MIT. Niri (GPL-3.0) and Umbriel are only run as separate test programs; none of their code is read or shipped.
