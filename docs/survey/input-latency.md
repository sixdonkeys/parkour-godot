# Survey: input-latency

Fetched 2026-11-15. Excerpts are word for word from the address above them.

## Engine source 4.7.2 (MIT): where an input event waits — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/core/input/input.cpp

`Input::parse_input_event` (every event, from the operating system or from a script, comes through here; it may be called from any thread):

> if (use_accumulated_input) {
> 		if (buffered_events.is_empty() || !buffered_events.back()->get()->accumulate(p_event)) {
> 			buffered_events.push_back(p_event);
> 		}
> 	} else if (agile_input_event_flushing) {
> 		buffered_events.push_back(p_event);
> 	} else {
> 		_parse_input_event_impl(p_event, false);
> 	}

`Input::flush_buffered_events`:

> // The final delivery of the input event involves releasing the lock.
> 		// While the lock is released, another thread may lock it and add new events to the back.

## Engine source 4.7.2: the Linux main loop — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/linuxbsd/os_linuxbsd.cpp

> DisplayServer::get_singleton()->process_events(); // get rid of pending events

> if (Main::iteration()) {
> 			break;
> 		}

## Engine source 4.7.2: the Wayland display server — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/linuxbsd/wayland/display_server_wayland.cpp

The last lines of `DisplayServerWayland::process_events()`:

> wayland_thread.mutex.unlock();
>
> 	Input::get_singleton()->flush_buffered_events();

## Engine source 4.7.2: one iteration — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/main/main.cpp

Inside `Main::iteration()`, at the top of each physics step:

> if (Input::get_singleton()->is_agile_input_event_flushing()) {
> 			Input::get_singleton()->flush_buffered_events();
> 		}

> Engine::get_singleton()->_physics_interpolation_fraction = advance.interpolation_fraction;

## Engine class reference 4.7.2: Input — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Input.xml

> If [code]true[/code], similar input events sent by the operating system are accumulated. When input accumulation is enabled, all input events generated during a frame will be merged and emitted when the frame is done rendering. Therefore, this limits the number of input method calls per second to the rendering FPS.

> Input accumulation can be disabled to get slightly more precise/reactive input at the cost of increased CPU usage.

> Sends all input events which are in the current buffer to the game loop. These events may have been buffered as a result of accumulated input ([member use_accumulated_input]) or agile input flushing ([member ProjectSettings.input_devices/buffering/agile_event_flushing]).

> Feeds an [InputEvent] to the game. Can be used to artificially trigger input events from code. Also generates [method Node._input] calls.

## Engine class reference 4.7.2: ProjectSettings — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml

`input_devices/buffering/agile_event_flushing`:

> If [code]true[/code], key/touch/joystick events will be flushed just before every idle and physics frame.

> [b]Note:[/b] Currently implemented only on Android.

`physics/common/physics_interpolation`:

> If [code]true[/code], the renderer will interpolate the transforms of objects (both physics and non-physics) between the last two transforms, so that smooth motion is seen even when physics ticks do not coincide with rendered frames.

## Godot docs (CC BY 3.0): "Fixing jitter, stutter and input lag" — https://raw.githubusercontent.com/godotengine/godot-docs/9adca4c1c72917bfe1b7be3108abed5ce26696a6/tutorials/rendering/jitter_stutter.rst

> Input lag refers to visible on-screen delay when performing actions with the mouse, keyboard, controller or touchscreen. It can be related to game code, engine code or external factors (such as hardware).

> Enabling physics interpolation will increase input lag for behavior
>     that depends on the physics tick, such as player movement.

> On platforms that support disabling V-Sync, input lag can be made less
> noticeable by disabling V-Sync in the project settings.

> another way to reduce
> visual latency when V-Sync is enabled is to use double-buffered V-Sync instead of
> the default triple-buffered V-Sync. Since Godot 4.3, this can be achieved by
> reducing the **Display > Window > V-Sync > Swapchain Image Count** project
> setting to ``2``.

> Increasing the number of physics iterations per second can also reduce
> physics-induced input latency. This is especially noticeable when using physics
> interpolation (which improves smoothness but increases latency).

> If you are reporting input lag problems, please include a capture made with a
> high speed camera (such as your phone's slow motion video mode). The capture
> **must** have both the screen and the input device visible so that the number of
> frames between an input and the on-screen result can be counted.

## Godot docs: physics interpolation, introduction — https://raw.githubusercontent.com/godotengine/godot-docs/9adca4c1c72917bfe1b7be3108abed5ce26696a6/tutorials/physics/interpolation/physics_interpolation_introduction.rst

> To be exact, we are estimating the position of the object *between
> 1 and 2 ticks* into the past.

> The most significant effect is there can be a slight delay to input,
> which can be a factor in fast twitch games. In some of these fast input
> situations, you may wish to turn off physics interpolation and use a different
> scheme, or use a high tick rate, which mitigates these delays.

## Godot docs: controllers, gamepads and joysticks — https://raw.githubusercontent.com/godotengine/godot-docs/9adca4c1c72917bfe1b7be3108abed5ce26696a6/tutorials/inputs/controllers_gamepads_joysticks.rst

> The downside is that without a deadzone system, an analog axis' strength will
> never be equal to ``0.0`` due to how the controller is physically built.

> # This handles deadzone in a correct way for most use cases.
>     # The resulting deadzone will have a circular shape as it generally should.
