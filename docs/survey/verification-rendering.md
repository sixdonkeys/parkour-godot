# Survey: verification-rendering

Excerpts quoted verbatim from the sources consulted on 2026-11-15.

## Godot command line tutorial — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/editor/command_line_tutorial.rst

> | ``--headless``                           | |release| Enable headless mode (``--display-driver headless --audio-driver Dummy``). Useful for servers and with ``--script``.

> | ``--write-movie <file>``                 | |release| Run the engine in a way that a movie is written (usually with .avi or .png extension).

> | ``--fixed-fps <fps>``          | |release| Force a fixed number of frames per second. This setting disables real-time synchronization.

> Using the ``--headless`` command line argument is **required** on platforms
> that do not have GPU access (such as continuous integration). On platforms
> with GPU access, ``--headless`` prevents a window from spawning while the
> project is exporting.

## Creating movies — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/animation/creating_movies.rst

> Godot can record **non-real-time** video and audio from any 2D or 3D project.
> This kind of recording is also called *offline rendering*.

> **This feature is not designed for capturing real-time footage during gameplay.**

## RenderingServer class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/RenderingServer.xml

> Returns the name of the video adapter (e.g. "GeForce GTX 1080/PCIe/SSE2").
> [b]Note:[/b] When running a headless or server binary, this function returns an empty string.

> Returns the GPU time taken to render the last frame in milliseconds. To get a complete readout of GPU time spent to render the scene, sum the render times of all viewports that are drawn every frame. Unlike [method Engine.get_frames_per_second], this method accurately reflects GPU utilization even if framerate is capped via V-Sync or [member Engine.max_fps].

> Emitted at the end of the frame, after the RenderingServer has finished updating all the Viewports.

## Viewport class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Viewport.xml

> Returns the viewport's texture.
> [b]Note:[/b] When trying to store the current texture (e.g. in a file), it might be completely black or outdated if used too early, especially when used in e.g. [method Node._ready]. To make sure the texture you get is correct, you can await [signal RenderingServer.frame_post_draw] signal.

## Window class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Window.xml

> The content's base size in "virtual" pixels. Not to be confused with [member size], which sets the actual window's physical size in pixels. If set to a value greater than [code]0[/code] and [member content_scale_mode] is set to a value other than [constant CONTENT_SCALE_MODE_DISABLED], the [Window]'s content will be scaled when the window is resized to a different size.

## OS and Logger class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/OS.xml, https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Logger.xml

> Add a custom logger to intercept the internal message stream.

> Custom logger to receive messages from the internal error/warning stream. Loggers are registered via [method OS.add_logger].

> Returns the video adapter driver name and version for the user's currently active graphics card, as a [PackedStringArray].

> [b]Note:[/b] This method is only supported on Linux/BSD and Windows when not running in headless mode. On other platforms, it returns an empty array.

> Returns the amount of static memory being used by the program in bytes. Only works in debug builds.

## Local probe — `vulkaninfo` on the Fedora laptop, 2026-11-15 (outside the sandbox)

> GPU0:
> 	deviceName        = Apple M1 Pro (G13S C0)
> GPU1:
> 	deviceName        = llvmpipe (LLVM 22.1.8, 128 bits)
