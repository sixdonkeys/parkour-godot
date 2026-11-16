class_name MovementTuning
extends Resource
## Every movement number in the game (decision movement-numbers). Meters,
## seconds, kilograms. Nothing else holds a movement number; the measured
## results are written to docs/metrics.json when `traversal` closes.

@export_group("Body")
@export var height := 1.8
@export var radius := 0.3
@export var mass := 75.0
## Where a first-person camera sits above the feet.
@export var eye_height := 1.65

@export_group("Ground")
## Reached quickly, so the first step is immediate.
@export var run_speed := 6.0
## Built slowly on top of run speed; this is the momentum worth keeping.
@export var top_speed := 10.0
## Set at once on the first tick of movement from rest (decision input-latency).
@export var start_speed := 1.5
@export var run_accel := 20.0
@export var sprint_accel := 2.0
@export var brake := 24.0
## Sideways speed shed per second while turning; a turn of up to 90 degrees
## keeps the body's speed.
@export var grip := 30.0
## Speed limits for moving sideways and backward, as a share of run speed.
@export var side_speed_factor := 0.85
@export var back_speed_factor := 0.7
@export_range(0.0, 89.0) var max_slope_degrees := 46.0
@export var step_height := 0.35
## How far down the body is kept on the ground: the step height, so a step
## that can be climbed can be walked down without leaving the ground.
@export var floor_snap := 0.35

@export_group("Jump")
@export var jump_height := 0.95
@export var time_to_peak := 0.34
@export var time_to_fall := 0.30
## Gravity multiplier while still rising after jump is released (short hop).
@export var release_gravity_factor := 2.5
@export var coyote_ticks := 12
@export var buffer_ticks := 14
@export var max_fall_speed := 40.0

@export_group("Air")
@export var air_accel := 8.0
## Air steering can add speed only up to this.
@export var air_speed := 4.0

@export_group("Look")
## Radians per second at full deflection of the look stick.
@export var stick_look_speed := 3.5
@export var stick_dead_zone := 0.2
@export_range(0.0, 89.0) var pitch_limit_degrees := 85.0


func jump_speed() -> float:
	return 2.0 * jump_height / time_to_peak


## Positive, meters per second squared.
func rise_gravity() -> float:
	return 2.0 * jump_height / (time_to_peak * time_to_peak)


func fall_gravity() -> float:
	return 2.0 * jump_height / (time_to_fall * time_to_fall)


func describe() -> Dictionary:
	var d := {}
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and p["type"] in [TYPE_FLOAT, TYPE_INT]:
			d[p["name"]] = get(p["name"])
	d["jump_speed"] = jump_speed()
	d["rise_gravity"] = rise_gravity()
	d["fall_gravity"] = fall_gravity()
	return d
