class_name PlayerBody
extends StairsCharacter
## The player's body and its momentum, independent of any camera (decision
## player-body). A kinematic CharacterBody3D: one move per physics tick,
## reading only its InputSource. Facing (`yaw`, `pitch`) is simulation state
## fed by the source's look; a camera reads it, the body never reads a camera.
## Nothing here assumes one body: make as many as there are player slots.

signal jumped
signal landed(speed: float)
signal left_ground

enum State { GROUNDED, AIRBORNE }

const LAYER_WORLD := 1
const LAYER_PLAYERS := 2
const SLOT_COLORS: Array[Color] = [Color(0.92, 0.45, 0.1), Color(0.1, 0.55, 0.9), Color(0.2, 0.75, 0.3),
	Color(0.85, 0.2, 0.6), Color(0.9, 0.85, 0.2), Color(0.5, 0.3, 0.85), Color(0.1, 0.8, 0.8), Color(0.75, 0.75, 0.75)]

@export var tuning: MovementTuning

var state: State = State.AIRBORNE
## Facing, radians. Yaw turns left as it grows (the engine's sense); looking
## right lowers it. Pitch is up when positive.
var yaw := 0.0
var pitch := 0.0
var player_id := 0
var is_ghost := false
## Whether this body is stopped by other players' bodies (ghosts never are).
var collide_with_players := true
## Ticks this body has simulated.
var tick := 0
## This tick's world-space wish direction times its strength (0..1); what
## "input asks for movement" means to the instruments.
var wish := Vector3.ZERO
## Set false to hold the body still under another system's control (traversal).
var simulate := true

var _source: InputSource
var _coyote := 0
var _buffer := 0
var _jump_held := false
var _rising := false
## This body's own ground state, as of the end of its last move.
var _on_floor := false
## Set by launch() and teleport(): the body leaves the ground this tick.
var _off_floor := false
var _launched := false
## Rising from the player's own jump (a launch is not cut short by letting go of jump).
var _own_jump := false
var _collider: CollisionShape3D
var _visual: Node3D


func _init() -> void:
	if tuning == null:
		tuning = MovementTuning.new()
	_collider = CollisionShape3D.new()
	_collider.name = "Collider"
	var shape := CylinderShape3D.new()
	shape.margin = 0.002
	_collider.shape = shape
	add_child(_collider)
	_visual = _make_placeholder()
	add_child(_visual)


func _ready() -> void:
	MovementActions.ensure()
	apply_tuning()
	_apply_layers()
	super._ready()


## A body for a player slot, added under `parent` at `at`, facing `facing_yaw`.
static func spawn(slot: PlayerSlot, parent: Node, at: Vector3, facing_yaw := 0.0, with_tuning: MovementTuning = null) -> PlayerBody:
	var b := PlayerBody.new()
	if with_tuning:
		b.tuning = with_tuning
	b.name = "PlayerBody%d" % slot.player_id
	b.player_id = slot.player_id
	b.is_ghost = slot.is_ghost
	b.set_input_source(slot.input)
	parent.add_child(b)
	b.teleport(at, facing_yaw)
	b._tint(slot)
	slot.body = b
	return b


func set_input_source(src: InputSource) -> void:
	_source = src


func apply_tuning() -> void:
	var shape := _collider.shape as CylinderShape3D
	shape.height = tuning.height
	shape.radius = tuning.radius
	_collider.position = Vector3(0, tuning.height * 0.5, 0)
	_step_height = tuning.step_height
	floor_max_angle = deg_to_rad(tuning.max_slope_degrees)
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_block_on_wall = true
	floor_snap_length = tuning.floor_snap
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY


func _apply_layers() -> void:
	collision_layer = 0 if is_ghost else (1 << (LAYER_PLAYERS - 1))
	collision_mask = 1 << (LAYER_WORLD - 1)
	if collide_with_players and not is_ghost:
		collision_mask |= 1 << (LAYER_PLAYERS - 1)


## Put the body somewhere at rest (spawn, restart at a checkpoint).
func teleport(at: Vector3, facing_yaw := 0.0) -> void:
	global_position = at
	yaw = facing_yaw
	pitch = 0.0
	rotation = Vector3(0, yaw, 0)
	velocity = Vector3.ZERO
	wish = Vector3.ZERO
	state = State.AIRBORNE
	_on_floor = false
	grounded = false
	was_grounded = false
	_coyote = 0
	_buffer = 0
	_rising = false
	_launched = false
	_own_jump = false
	_off_floor = true
	reset_physics_interpolation()


## Throw the body: its velocity becomes `v` and it leaves the ground (jump
## pads, hazards, and the jump instrument's known-speed launch).
func launch(v: Vector3) -> void:
	velocity = v
	_rising = v.y > 0.0
	_launched = true
	_off_floor = true
	_own_jump = false
	_coyote = 0
	_buffer = 0


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not simulate:
		return
	tick += 1
	var inp: Dictionary = _source.sample(tick) if _source else {}
	_step(inp, delta)


func _step(inp: Dictionary, dt: float) -> void:
	var t := tuning
	# Facing: mouse or trackpad look arrives in radians; the look stick is a rate.
	var stick := _round_dead_zone(Vector2(
		float(inp.get(MovementActions.LOOK_RIGHT, 0.0)) - float(inp.get(MovementActions.LOOK_LEFT, 0.0)),
		float(inp.get(MovementActions.LOOK_DOWN, 0.0)) - float(inp.get(MovementActions.LOOK_UP, 0.0))), t.stick_dead_zone)
	var limit := deg_to_rad(t.pitch_limit_degrees)
	yaw = wrapf(yaw - float(inp.get("look_x", 0.0)) - stick.x * t.stick_look_speed * dt, -PI, PI)
	pitch = clampf(pitch - float(inp.get("look_y", 0.0)) - stick.y * t.stick_look_speed * dt, -limit, limit)
	rotation = Vector3(0, yaw, 0)

	# Wish direction: move input turned by the facing. x is right, y is back.
	var mv := _round_dead_zone(Vector2(
		float(inp.get(MovementActions.MOVE_RIGHT, 0.0)) - float(inp.get(MovementActions.MOVE_LEFT, 0.0)),
		float(inp.get(MovementActions.MOVE_BACK, 0.0)) - float(inp.get(MovementActions.MOVE_FORWARD, 0.0))), t.stick_dead_zone)
	var strength := mv.length()
	var dir := Vector3.ZERO
	if strength > 0.0:
		dir = Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, yaw) / strength
	wish = dir * strength

	var jump_down := float(inp.get(MovementActions.JUMP, 0.0)) > 0.5
	if jump_down and not _jump_held:
		_buffer = t.buffer_ticks
	elif _buffer > 0:
		_buffer -= 1
	_jump_held = jump_down

	var on_floor := _on_floor and not _off_floor
	_off_floor = false
	if on_floor:
		_coyote = t.coyote_ticks
	elif _coyote > 0:
		_coyote -= 1

	var h := Vector3(velocity.x, 0, velocity.z)
	if on_floor:
		h = _ground_velocity(h, dir, strength, mv, dt)
	else:
		h = _air_velocity(h, dir, strength, dt)

	var vy := velocity.y if not on_floor else 0.0
	var jumped_now := _launched
	_launched = false
	if _buffer > 0 and _coyote > 0:
		vy = t.jump_speed()
		_buffer = 0
		_coyote = 0
		_rising = true
		_own_jump = true
		jumped_now = true
		jumped.emit()
	if vy <= 0.0:
		_rising = false
		_own_jump = false
	var g := 0.0
	if not on_floor or jumped_now:
		g = t.rise_gravity() if vy > 0.0 else t.fall_gravity()
		if vy > 0.0 and _own_jump and not jump_down:
			g *= t.release_gravity_factor

	# Move with the mid-tick vertical speed, so a jump is the exact parabola
	# whatever the tick rate.
	var vy_mid := maxf(vy - 0.5 * g * dt, -t.max_fall_speed)
	velocity = Vector3(h.x, vy_mid, h.z)
	desired_velocity = wish
	floor_snap_length = 0.0 if (_rising or vy_mid > 0.0) else t.floor_snap
	# The step-up test goes by this body's own ground state, which is steadier
	# than the engine's flag on stairs.
	force_stair_step = on_floor
	var y_before := global_position.y
	stair_step_up()
	var stepped := global_position.y > y_before + 0.0005
	move_and_slide()
	stair_step_down()

	var now_floor := is_on_floor()
	if not now_floor and on_floor and not jumped_now and vy_mid <= 0.0:
		# Just lifted onto a step, the engine can miss the floor for a tick (the
		# body overlaps the tread by a sliver). The step test already found
		# walkable ground there, so stay grounded; this snap, or the next
		# tick's, makes the engine agree.
		apply_floor_snap()
		now_floor = is_on_floor() or stepped
	_on_floor = now_floor
	var post_h := Vector3(velocity.x, 0, velocity.z)
	if is_on_wall():
		# A wall takes the part of the velocity that points into it, never adds.
		h = post_h.limit_length(h.length())
	elif not now_floor:
		h = post_h
	if now_floor:
		if not on_floor:
			# Landed. On a moving surface the body's speed is from here on
			# measured against the surface.
			var pv := get_platform_velocity()
			h -= Vector3(pv.x, 0, pv.z)
			_rising = false
			state = State.GROUNDED
			landed.emit(maxf(-vy_mid, 0.0))
		velocity = Vector3(h.x, 0.0, h.z)
	else:
		velocity = Vector3(h.x, maxf(velocity.y - 0.5 * g * dt, -t.max_fall_speed), h.z)
		if state == State.GROUNDED:
			state = State.AIRBORNE
			left_ground.emit()


## Ground: the velocity turns toward the wish direction, shedding only its
## sideways part at the grip rate, so a turn keeps the speed. Speed builds
## quickly to run speed, then slowly to top speed.
func _ground_velocity(h: Vector3, dir: Vector3, strength: float, mv: Vector2, dt: float) -> Vector3:
	var t := tuning
	if strength <= 0.0:
		return h.move_toward(Vector3.ZERO, t.brake * dt)
	var target := _speed_limit(-mv.y / strength) * strength
	var speed0 := h.length()
	var along := h.dot(dir)
	var side := (h - dir * along).move_toward(Vector3.ZERO, t.grip * dt)
	if along < 0.0:
		return dir * minf(along + t.brake * dt, 0.0) + side
	along = maxf(along, sqrt(maxf(speed0 * speed0 - side.length_squared(), 0.0)))
	if along < target:
		if speed0 < 0.1:
			along = maxf(along, minf(t.start_speed, target))
		var a := t.run_accel if along < t.run_speed else t.sprint_accel
		along = minf(along + a * dt, target)
	elif along > target:
		along = maxf(along - t.brake * dt, target)
	return dir * along + side


## Air: nothing slows the body. Steering can turn or shorten the velocity and
## can add speed only up to the air-control cap.
func _air_velocity(h: Vector3, dir: Vector3, strength: float, dt: float) -> Vector3:
	if strength <= 0.0:
		return h
	var cap := maxf(h.length(), tuning.air_speed)
	return (h + dir * (tuning.air_accel * strength * dt)).limit_length(cap)


## Top speed for a wish direction given how far forward of the facing it
## points (1 ahead, 0 sideways, -1 behind).
func _speed_limit(forward: float) -> float:
	var t := tuning
	var side := t.run_speed * t.side_speed_factor
	if forward >= 0.7:
		return t.top_speed
	if forward >= 0.0:
		return lerpf(side, t.top_speed, forward / 0.7)
	return lerpf(side, t.run_speed * t.back_speed_factor, -forward)


## A round dead zone, rescaled so the edge of the zone reads 0 and full
## deflection reads 1. Keyboard diagonals come in at 1.41 and are cut to 1.
static func _round_dead_zone(v: Vector2, zone: float) -> Vector2:
	var m := v.length()
	if m <= zone:
		return Vector2.ZERO
	return v / m * minf((m - zone) / (1.0 - zone), 1.0)


# --- placeholder looks (until `character` closes) -------------------------------

## Show or hide the placeholder (a first-person view hides its own body).
func set_placeholder_visible(shown: bool) -> void:
	_visual.visible = shown


func _make_placeholder() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var body := MeshInstance3D.new()
	body.name = "Torso"
	var cap := CapsuleMesh.new()
	cap.radius = tuning.radius
	cap.height = tuning.height
	body.mesh = cap
	body.position = Vector3(0, tuning.height * 0.5, 0)
	root.add_child(body)
	var visor := MeshInstance3D.new()
	visor.name = "Visor"
	var box := BoxMesh.new()
	box.size = Vector3(tuning.radius * 1.3, 0.14, 0.2)
	visor.mesh = box
	visor.position = Vector3(0, tuning.eye_height, -tuning.radius * 0.8)
	root.add_child(visor)
	# A pack on the back, so the facing reads from behind as well.
	var pack := MeshInstance3D.new()
	pack.name = "Pack"
	var pack_box := BoxMesh.new()
	pack_box.size = Vector3(tuning.radius * 1.1, 0.5, 0.16)
	pack.mesh = pack_box
	pack.position = Vector3(0, tuning.height * 0.68, tuning.radius * 0.95)
	root.add_child(pack)
	return root


func _tint(slot: PlayerSlot) -> void:
	var c: Color = SLOT_COLORS[(slot.player_id - 1) % SLOT_COLORS.size()]
	var look_color = slot.look.get("color", null)
	if look_color is Color:
		c = look_color
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	if is_ghost:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.45
	(_visual.get_node("Torso") as MeshInstance3D).material_override = m
	var v := StandardMaterial3D.new()
	v.albedo_color = Color(0.08, 0.08, 0.1)
	v.roughness = 0.2
	(_visual.get_node("Visor") as MeshInstance3D).material_override = v
	var pk := StandardMaterial3D.new()
	pk.albedo_color = c.darkened(0.55)
	pk.roughness = 0.7
	(_visual.get_node("Pack") as MeshInstance3D).material_override = pk
