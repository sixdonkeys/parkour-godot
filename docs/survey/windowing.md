# Survey: windowing

## Godot Wayland display server source (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/linuxbsd/wayland/display_server_wayland.cpp

> 		case DisplayServerEnums::CONTEXT_ENGINE:
> 		default: {
> 			String config_name = GLOBAL_GET("application/config/name");
> 			if (config_name.length() != 0) {
> 				app_id = config_name;
> 			} else {
> 				app_id = "org.godotengine.Godot";
> 			}

## ProjectSettings class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml

> [code]"canvas_items"[/code]: The base size specified in width and height in the project settings is stretched to cover the whole screen (taking [member display/window/stretch/aspect] into account). This means that everything is rendered directly at the target resolution. 3D is unaffected, while in 2D, there is no longer a 1:1 correspondence between sprite pixels and screen pixels, which may result in scaling artifacts.

> [b]Note:[/b] Certain window managers can be configured to ignore the non-resizable status of a window. Do not rely on this setting as a guarantee that the window will [i]never[/i] be resizable.

> If [code]true[/code], subwindows are embedded in the main window (this is also called single-window mode).

> If [code]true[/code], displays the image specified in [member application/boot_splash/image] when the engine starts. If [code]false[/code], only displays the plain color specified in [member application/boot_splash/bg_color].

## DisplayServer class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/DisplayServer.xml

> Captures the mouse. The mouse will be hidden and its position locked at the center of the window manager's window.

> Full screen mode with full multi-window support.
> Full screen window covers the entire display area of a screen and has no decorations. The display's video mode is not changed.

> A single window full screen mode. This mode has less overhead, but only one window can be open on a given screen at a time (opening a child window or application switching will trigger a full screen transition).

## Local probes, 2026-11-15

`niri --help` (niri 26.04):
> Usage: niri [OPTIONS] [-- <COMMAND>...]
>        niri <SUBCOMMAND>

`umbriel --help` (umbriel 0.1.0):
> Usage: umbriel [-s <command>] [-c <config>]   run the compositor
>   windows                        list windows (app id and title)
>   focused-window                 print the focused window (app id and title)

## Godot issue #123059, "hang on exit while joining event thread (wayland)" — https://github.com/godotengine/godot/issues/123059 (open, read 2026-11-15)

> Shutdown hangs with the wayland backend if the following occurs:
>
> 1. main thread sets `thread_done`
> 2. main thread calls `wl_display_roundtrip`
> 3. main thread processes the sync reply instead of waking the event thread as intended
> 4. main thread blocks on `events_thread.wait_to_finish()` forever
> 5. event thread enters `poll` with no timeout

## Godot PR #123760, "Wayland: Fix occasional hang on exit" — https://github.com/godotengine/godot/pull/123760 (closed, not merged)

> With the Wayland display server, the process sometimes never exits after quitting.

## Godot 4.7.2 source — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/linuxbsd/wayland/wayland_thread.cpp

> 		thread_data.thread_done.set();
>
> 		// By sending a roundtrip message we're unblocking the polling thread so that
> 		// it can realize that it's done and also handle every event that's left.
> 		wl_display_roundtrip(wl_display);
>
> 		events_thread.wait_to_finish();
