# Survey: tick-and-frame

## Engine class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Engine.xml

> The number of fixed iterations per second. This controls how often physics simulation and the [method Node._physics_process] method are run.

> Input can also become less responsive at low tick rates as there can be a gap between input being registered, and the response on the next physics tick. High tick rates give more accurate physics simulation, particularly for fast moving objects. For example, racing games may benefit from increasing the tick rate above the default 60.

> [b]Note:[/b] Only [member max_physics_steps_per_frame] physics ticks may be simulated per rendered frame at most. If more physics ticks have to be simulated per rendered frame to keep up with rendering, the project will appear to slow down (even if [code]delta[/code] is used consistently in physics calculations). Therefore, it is recommended to also increase [member max_physics_steps_per_frame] if increasing [member physics_ticks_per_second] significantly above its default value.

> How much physics ticks are synchronized with real time. If [code]0[/code] or less, the ticks are fully synchronized. Higher values cause the in-game clock to deviate more from the real clock, but they smooth out framerate jitters.

> [b]Note:[/b] When using a custom physics interpolation solution, or within a network game, it's recommended to disable the physics jitter fix by setting this property to [code]0[/code].

## Command line tutorial — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/editor/command_line_tutorial.rst

> | ``--fixed-fps <fps>``          | |release| Force a fixed number of frames per second. This setting disables real-time synchronization.

## Physics interpolation — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/physics/interpolation/physics_interpolation_introduction.rst and using_physics_interpolation.rst

> jitter, caused by this staircasing effect due to the discrepancy between physics

> values that are multiples of the user's monitor refresh rate (for stutter-free
