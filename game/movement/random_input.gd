class_name RandomInput
extends InputSource
## Seeded random input for the fuzz instrument. Deterministic: the same seed
## on the same course gives the same stream of action states, tick for tick.
##
## Two kinds of movement, mixed by the seed:
## - Probing: segments of at most `max_segment_ticks` (0.75 s) in any
##   direction, with turns, stops and jumps. Every second probing segment
##   points within 15 degrees of the opposite of where the push before it
##   ended (in world space).
## - Sprinting: forward for up to six seconds, straight or in a curve, so
##   the body reaches top speed and meets the course at it. Like a player,
##   the source lets go when the body has made no headway for half a second,
##   and the next push points the other way.
##
## So any three seconds of unbroken asking hold two opposite pushes. A body
## that has still not moved a centimeter is stuck, not leaning on a wall;
## that is what makes the stuck count mean something.

var rng := RandomNumberGenerator.new()
var max_segment_ticks := 90
var min_segment_ticks := 18
## Share of probing segments that ask for nothing.
var idle_share := 0.1
var sprint_share := 0.3
var jump_chance_per_tick := 1.0 / 150.0
var max_look_rate := 4.0

## The body's facing and place as of the last tick (see observe).
var yaw := 0.0
var segments := 0
var sprints := 0
var sprints_cut_short := 0
var jumps := 0

var _left := 0
var _move := Vector2.ZERO
var _look_rate := 0.0
var _look_pitch_rate := 0.0
var _flick := 0.0
var _use_stick_look := false
var _jump_left := 0
var _opposite_next := false
var _last_heading := 0.0
var _have_heading := false
var _sprinting := false
var _anchor := Vector3.ZERO
var _since_headway := 0


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


## Tell the source the body's facing after something else set it (a respawn).
func sync_yaw(body_yaw: float) -> void:
	yaw = body_yaw
	_have_heading = false
	_opposite_next = false
	_left = 0


## Called by the fuzz probe after each tick with the body's facing and place.
func observe(body_yaw: float, at: Vector3) -> void:
	yaw = body_yaw
	if at.distance_to(_anchor) >= 0.05:
		_anchor = at
		_since_headway = 0
	else:
		_since_headway += 1
	if _sprinting and _since_headway >= 60:
		sprints_cut_short += 1
		_left = 0


func sample(_tick: int) -> Dictionary:
	var dt := 1.0 / Engine.physics_ticks_per_second
	if _left <= 0:
		_next_segment()
	_left -= 1
	var look_x := _flick
	_flick = 0.0
	var d := {
		MovementActions.MOVE_FORWARD: maxf(-_move.y, 0.0), MovementActions.MOVE_BACK: maxf(_move.y, 0.0),
		MovementActions.MOVE_LEFT: maxf(-_move.x, 0.0), MovementActions.MOVE_RIGHT: maxf(_move.x, 0.0),
		MovementActions.LOOK_LEFT: 0.0, MovementActions.LOOK_RIGHT: 0.0,
		MovementActions.LOOK_UP: 0.0, MovementActions.LOOK_DOWN: 0.0,
	}
	if _use_stick_look:
		# The body turns 3.5 radians a second at full deflection of the look stick.
		var s := clampf(_look_rate / 3.5, -1.0, 1.0)
		d[MovementActions.LOOK_RIGHT] = maxf(s, 0.0)
		d[MovementActions.LOOK_LEFT] = maxf(-s, 0.0)
	else:
		look_x += _look_rate * dt
	d["look_x"] = look_x
	d["look_y"] = _look_pitch_rate * dt
	if _jump_left > 0:
		_jump_left -= 1
	elif rng.randf() < jump_chance_per_tick:
		_jump_left = rng.randi_range(1, 40)
		jumps += 1
	d[MovementActions.JUMP] = 1.0 if _jump_left > 0 else 0.0
	if _move != Vector2.ZERO:
		_last_heading = yaw - look_x + _local_heading(_move)
		_have_heading = true
	return d


func _next_segment() -> void:
	segments += 1
	var tps := float(Engine.physics_ticks_per_second)
	var was_sprinting := _sprinting
	_sprinting = false
	_since_headway = 0
	_use_stick_look = rng.randf() < 0.3
	_look_pitch_rate = rng.randf_range(-1.0, 1.0) if rng.randf() < 0.3 else 0.0
	if (_opposite_next or was_sprinting) and _have_heading:
		# Push opposite the last push, and hold the facing nearly still so it stays there.
		_left = rng.randi_range(min_segment_ticks, max_segment_ticks)
		var m := _random_move()
		_move = m
		var want := _last_heading + PI + deg_to_rad(rng.randf_range(-15.0, 15.0))
		_flick = -wrapf(want - _local_heading(m) - yaw, -PI, PI)
		_look_rate = rng.randf_range(-1.0, 1.0) * deg_to_rad(10.0) / (_left / tps)
		_use_stick_look = false
		_opposite_next = false
		return
	if rng.randf() < sprint_share:
		sprints += 1
		_sprinting = true
		_left = rng.randi_range(int(1.5 * tps), int(6.0 * tps))
		_move = Vector2(0, -1)
		_look_rate = 0.0 if rng.randf() < 0.5 else rng.randf_range(0.2, 1.5) * [-1.0, 1.0][rng.randi() % 2]
		return
	_left = rng.randi_range(min_segment_ticks, max_segment_ticks)
	if rng.randf() < idle_share:
		_move = Vector2.ZERO
		_look_rate = rng.randf_range(-max_look_rate, max_look_rate)
		return
	_move = _random_move()
	_look_rate = 0.0 if rng.randf() < 0.4 else rng.randf_range(-max_look_rate, max_look_rate)
	_opposite_next = true


## Mostly forward, as a player would; sometimes sideways or back; sometimes
## a half-pushed stick.
func _random_move() -> Vector2:
	var roll := rng.randf()
	var m: Vector2
	if roll < 0.55:
		m = Vector2(0, -1)
	elif roll < 0.7:
		m = Vector2([-1.0, 1.0][rng.randi() % 2], -1)
	elif roll < 0.85:
		m = Vector2([-1.0, 1.0][rng.randi() % 2], 0)
	else:
		m = Vector2([-1.0, 0.0, 1.0][rng.randi() % 3], 1)
	m = m.normalized()
	if rng.randf() < 0.3:
		m *= rng.randf_range(0.3, 1.0)
	return m


## How far a local move direction (x right, y back) is turned from straight
## ahead, in the same sense as yaw.
static func _local_heading(m: Vector2) -> float:
	return atan2(-m.x, -m.y)
