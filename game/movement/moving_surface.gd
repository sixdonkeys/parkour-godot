class_name MovingSurface
extends AnimatableBody3D
## A surface that moves and carries bodies standing on it. Its place is a
## pure function of the world tick (decision player-body): it slides between
## its start and start + travel and back, smoothly, once every period_ticks.

@export var travel := Vector3(4, 0, 0)
@export var period_ticks := 480
@export var phase_ticks := 0

var _origin := Vector3.ZERO
var _have_origin := false


func _ready() -> void:
	sync_to_physics = true
	_origin = global_position
	_have_origin = true
	global_position = position_at(WorldClock.tick_for(self))
	reset_physics_interpolation()


func _physics_process(_delta: float) -> void:
	global_position = position_at(WorldClock.tick_for(self))


func position_at(world_tick: int) -> Vector3:
	var origin := _origin if _have_origin else global_position
	var t := float(posmod(world_tick + phase_ticks, period_ticks)) / float(maxi(period_ticks, 1))
	return origin + travel * (0.5 - 0.5 * cos(TAU * t))


## The surface's velocity at a world tick, for instruments.
func velocity_at(world_tick: int) -> Vector3:
	var dt := 1.0 / Engine.physics_ticks_per_second
	return (position_at(world_tick) - position_at(world_tick - 1)) / dt
