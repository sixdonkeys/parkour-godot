# Survey: player-body

Everything here was fetched on 2026-11-15, in the session that wrote the record. Each excerpt is word for word from the address above it. Licences were read from each repository's own `LICENSE` file, not from a listing.

## Engine class reference 4.7.2: CharacterBody3D — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/CharacterBody3D.xml

> [CharacterBody3D] is a specialized class for physics bodies that are meant to be user-controlled. They are not affected by physics at all, but they affect other physics bodies in their path.

> Sets a snapping distance. When set to a value different from [code]0.0[/code], the body is kept attached to slopes when calling [method move_and_slide].

> Maximum angle (in radians) where a slope is still considered a floor (or a ceiling), rather than a wall, when calling [method move_and_slide]. The default value equals 45 degrees.

> If [code]true[/code], the body will always move at the same speed on the ground no matter the slope. Note that you need to use [member floor_snap_length] to stick along a downward slope at constant speed.

> Sets the behavior to apply when you leave a moving platform. By default, to be physically accurate, when you leave the last platform velocity is applied.

> Returns the linear velocity of the platform at the last collision point. Only valid after calling [method move_and_slide].

> [b]Warning:[/b] The collision normal is not always the same as the surface normal.

The whole member and method list was read (this is the builder's reading, not a quotation). Members: `floor_block_on_wall`, `floor_constant_speed`, `floor_max_angle`, `floor_snap_length`, `floor_stop_on_slope`, `max_slides`, `motion_mode`, `platform_floor_layers`, `platform_on_leave`, `platform_wall_layers`, `safe_margin`, `slide_on_ceiling`, `up_direction`, `velocity`, `wall_min_slide_angle`. Methods: `apply_floor_snap`, the `get_floor_*`, `get_platform_*`, `get_slide_*`, `get_wall_normal`, `get_last_motion`, `get_position_delta`, `get_real_velocity`, the `is_on_*` family and `move_and_slide`. There is nothing for stepping up onto a ledge or stair: the brief's lead is confirmed.

## Engine class reference 4.7.2: SeparationRayShape3D — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/SeparationRayShape3D.xml

> For example, a [SeparationRayShape3D] next to a character can allow it to instantly move up when touching stairs.

## Engine class reference 4.7.2: AnimatableBody3D — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/AnimatableBody3D.xml

> When [AnimatableBody3D] is moved, its linear and angular velocity are estimated and used to affect other physics bodies in its path. This makes it useful for moving platforms, doors, and other moving objects.

## Engine class reference 4.7.2: ProjectSettings (Jolt motion queries) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/ProjectSettings.xml

> If [code]true[/code], enables Jolt's enhanced internal edge removal during motion queries. This can help alleviate ghost collisions, but only with edges within a single body, meaning edges between separate bodies can still cause ghost collisions.

## Andicraft, stairs-character (MIT) — https://github.com/Andicraft/stairs-character at commit 5403d02f6b64b49a1d1bd7af11dd51a6edfc9e6c

Licence file (`LICENSE`), first line and grant:

> Copyright © 2023 Andrea Jörgensen

> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction

`README.md`:

> A simple to use class that enables your CharacterBody3D to handle stairs properly.

> Mainly tested with the Jolt physics engine and cylinder colliders, not guaranteed to work well with anything else - but try it!

`addons/stairs-character/stairs_character.gd`:

> # Use was_grounded instead of is_on_floor() - because of the stair step mechanism, sometimes this
> # script will snap the player to the floor, but is_on_floor() will still read as false.

> # Raise up to ceiling - can't walk on steps if there's a low ceiling

> if (surfaceNormal.angle_to(Vector3.UP) > floor_max_angle): return #Can't stand on the thing we're trying to step on anyway

## Jeh3no, Godot-Advanced-State-Machine-First-Person-Controller (MIT) — https://github.com/Jeh3no/Godot-Advanced-State-Machine-First-Person-Controller at commit 7285087aa8eee52d2332083503147b91c88d943d

Licence file: "MIT License", "Copyright (c) 2024 Jeh3no".

`PlayerCharacter/StateMachine/player_character_script.gd`:

> @onready var jump_velocity: float = (2.0 * jump_height) / jump_time_to_peak

> @onready var jump_gravity: float = (-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
> @onready var fall_gravity: float = (-2.0 * jump_height) / (jump_time_to_fall * jump_time_to_fall)

> @export var hit_ground_cooldown: float = 0.1 #amount of time the character keep his accumulated speed before losing it (while being on ground)

> func _process(delta: float) -> void:
> 	wallrun_timer(delta)

`PlayerCharacter/StateMachine/run_state_script.gd` (direction comes from the camera holder, input from the global `Input`):

> if Input.is_action_just_pressed(play_char.jump_action):

> play_char.cam_holder.global_basis
> * Vector3(play_char.input_direction.x, 0.0, play_char.input_direction.y)

`PlayerCharacter/StateMachine/jump_state_script.gd` (floor snapping is switched off for the jump; a wall jump locks air steering briefly):

> if play_char.floor_snap_length != 0.0:
> 	play_char.floor_snap_length = 0.0

> if play_char.walljump_lock_in_air_movement_time <= 0.0: #lock the in air movement for a bit when walljumping, to not having the in air velocity decided by input crush the velocity of the walljump

## DeiranZ, godot-parkour-fps-controller (MIT) — https://github.com/DeiranZ/godot-parkour-fps-controller at commit 4e401a258a83ddabc1a02d66befac53657970eba

Licence file: "MIT License", "Copyright (c) 2022 DeiranZ".

`src/player/player.gd`:

> ## The code is very "prototypey" as of now

> gravity_vec = Vector3.UP * jump + get_platform_velocity()

> controller_velocity = controller_velocity.lerp(direction * speed, accel * delta)

## theRealUnd3rdog, Godot_Noshot_Controller, the NOSHOT controller (MIT, C#) — https://github.com/theRealUnd3rdog/Godot_Noshot_Controller at commit 15ac57ce0b7f1ab94c264fecd14e87732c8264fb

Licence file: "MIT License", "Copyright (c) 2023 theRealUnd3rdog".

`Scripts/NewStepper.cs` (a ray ahead of the body finds the step and the body is placed on it):

> // Perform the snapping to step here if step is found

> _characterBody.GlobalPosition = stepPosition;

`Scripts/PlayerMovement.cs`:

> [Export] private float _coyoteTime = 0.5f;

> direction = direction.Lerp((Transform.Basis * new Vector3(inputDir.X, 0f, inputDir.Y)).Normalized(),

## GDQuest, godot-4-3d-third-person-controller (code MIT; art CC BY-NC-SA) — https://github.com/gdquest-demos/godot-4-3d-third-person-controller at commit b3bd6e81084f568be8aa44a69a0c2b1e52e806b3

`LICENSE`:

> 1. The demo's source code (script files, scene files, shaders, and generally all Godot-generated resources) is available under the MIT license.
> 2. Art assets (image textures and 3D models) are [CC-BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

`player/player.gd` (only the script was fetched; none of its art):

> # We separate out the y velocity to not interpolate on the gravity

> velocity = velocity.lerp(_move_direction * move_speed, acceleration * delta)

## Godot demo projects (MIT) — https://github.com/godotengine/godot-demo-projects at commit b761b4cd5718a7118f2c95eb55f181d0a5f004f1

`LICENSE.md`:

> Copyright (c) 2014-present Godot Engine contributors. \
> Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

`3d/platformer/player/player.gd`:

> const AIR_ACCEL_FACTOR: float = 0.5

> # Reduce jump height if releasing the jump key before reaching the apex.

`3d/physics_interpolation/player.gd` (the facing is a yaw number fed by look input; the camera reads the body's interpolated transform, not the other way round):

> _yaw -= input_event.screen_relative.x * MOUSE_SENSITIVITY * 0.001

> var target: Vector3 = $Rig/Head.get_global_transform_interpolated().origin

## Other step-up projects looked up (licence check only, code not taken)

GitHub's repository API on 2026-11-15: `mrezai/GodotStairs` MIT (its `LICENSE` reads "Copyright (c) 2022 Mohammad Rezai."), `majikayogames/SimpleFPSController` CC0-1.0, `mrjshzk/StairsCharacter3D` Unlicense, `PantheraDigital/GodotCharacterStep` MIT.
