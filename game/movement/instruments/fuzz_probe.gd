class_name FuzzProbe
extends Node
## The fuzz instrument: watches bodies driven by seeded random input and
## counts what the budget wants to be zero (ARCHITECTURE.md, Measured events):
## - fall through the world: a body below the course's kill plane, or a body
##   inside static collision;
## - stuck state: a body that has not left a 1 cm ball for 3 s while its
##   input asked for movement the whole time;
## - non-finite value: any NaN or infinity in a body's position, velocity or
##   facing.
## A fall into a pit the course expects is counted apart and the body is put
## back at a seeded spawn point, as a restart would. Runs after the bodies in
## each tick.

const STUCK_TICKS := 360
const STUCK_RADIUS := 0.01
const ASKING := 0.1
const EMBED_SHRINK := 0.05
const MAX_EVENTS := 60

var course: MetricsCourse
var bodies: Array[PlayerBody] = []
var rng := RandomNumberGenerator.new()
var seed_value := 1
## Put every body at a fresh spawn point this often (0 = never), so ten
## minutes cover the whole course rather than one corner of it.
var respawn_every_ticks := 0

var ticks := 0
var below_kill_plane := 0
var embedded_in_static := 0
var stuck_states := 0
var non_finite := 0
var expected_falls := 0
var respawns := 0
var events: Array = []
var regions: Dictionary = {}
var counts := {"jumped": 0, "landed": 0, "left_ground": 0}
var distance := 0.0
var max_speed := 0.0
var max_fall_speed := 0.0
var max_height := -INF

var _kill_y := -12.0
var _expected_y = null
var _per: Array = []
var _query: PhysicsShapeQueryParameters3D
var _query_shape: CylinderShape3D


func _init() -> void:
	process_physics_priority = 1000


func setup(p_course: MetricsCourse, p_bodies: Array[PlayerBody], p_seed: int, p_respawn_every_ticks := 0) -> void:
	course = p_course
	bodies = p_bodies
	seed_value = p_seed
	rng.seed = p_seed * 7919 + 17
	respawn_every_ticks = p_respawn_every_ticks
	_kill_y = float(course.data.get("kill_plane_y", -12.0))
	_expected_y = course.data.get("expected_fall_below_y", null)
	for b in bodies:
		_per.append({"anchor": b.global_position, "anchor_tick": 0, "asking": 0, "embedded": false,
			"last": b.global_position, "since_respawn": 0})
		b.jumped.connect(func(): counts["jumped"] += 1)
		b.landed.connect(func(speed: float):
			counts["landed"] += 1
			max_fall_speed = maxf(max_fall_speed, speed))
		b.left_ground.connect(func(): counts["left_ground"] += 1)


func _physics_process(_delta: float) -> void:
	ticks += 1
	for i in bodies.size():
		_watch(i)


func _watch(i: int) -> void:
	var b := bodies[i]
	var s: Dictionary = _per[i]
	var pos := b.global_position
	var src := b._source as RandomInput
	if src:
		src.observe(b.yaw, pos)
	if not (pos.is_finite() and b.velocity.is_finite() and is_finite(b.yaw) and is_finite(b.pitch)):
		non_finite += 1
		_event("non_finite", i, s["last"], {"velocity": str(b.velocity), "position": str(pos), "yaw": b.yaw})
		_respawn(i)
		return
	distance += Vector2(pos.x - s["last"].x, pos.z - s["last"].z).length()
	s["last"] = pos
	max_speed = maxf(max_speed, b.horizontal_speed())
	max_height = maxf(max_height, pos.y)
	var region := course.region_at(pos)
	regions[region] = int(regions.get(region, 0)) + 1
	if pos.y < _kill_y:
		below_kill_plane += 1
		_event("below_kill_plane", i, pos, {"region": region})
		_respawn(i)
		return
	if _inside_static(b):
		if not s["embedded"]:
			s["embedded"] = true
			embedded_in_static += 1
			_event("embedded_in_static", i, pos, {"region": region})
	else:
		s["embedded"] = false
	if _expected_y != null and pos.y < float(_expected_y) and b.state == PlayerBody.State.GROUNDED:
		expected_falls += 1
		_respawn(i)
		return
	# Stuck: asked to move for three seconds on end and never left a 1 cm ball.
	if pos.distance_to(s["anchor"]) >= STUCK_RADIUS:
		s["anchor"] = pos
		s["anchor_tick"] = ticks
	s["asking"] = int(s["asking"]) + 1 if b.wish.length() > ASKING else 0
	if int(s["asking"]) >= STUCK_TICKS and ticks - int(s["anchor_tick"]) >= STUCK_TICKS:
		stuck_states += 1
		_event("stuck", i, pos, {"region": region, "state": PlayerBody.State.keys()[b.state],
			"wish": str(b.wish), "on_wall": b.is_on_wall(), "on_floor": b.is_on_floor()})
		_respawn(i)
		return
	s["since_respawn"] = int(s["since_respawn"]) + 1
	if respawn_every_ticks > 0 and int(s["since_respawn"]) >= respawn_every_ticks:
		_respawn(i)


func _inside_static(b: PlayerBody) -> bool:
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		_query_shape = CylinderShape3D.new()
		_query.shape = _query_shape
		_query.collision_mask = 1 << (PlayerBody.LAYER_WORLD - 1)
	_query_shape.radius = b.tuning.radius - EMBED_SHRINK
	_query_shape.height = b.tuning.height - 2.0 * EMBED_SHRINK
	_query.transform = Transform3D(Basis.IDENTITY, b.global_position + Vector3(0, b.tuning.height * 0.5, 0))
	_query.exclude = [b.get_rid()]
	for hit in b.get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var c = hit.get("collider")
		if c is StaticBody3D and not (c is AnimatableBody3D):
			return true
	return false


func _respawn(i: int) -> void:
	var spawns: Array = course.data.get("spawns", [])
	if spawns.is_empty():
		return
	var sp: Dictionary = spawns[rng.randi() % spawns.size()]
	var b := bodies[i]
	var at := course.spawn_position(sp) + Vector3(0, 0.05, 0)
	b.teleport(at, deg_to_rad(float(sp.get("yaw_deg", 0.0))) + rng.randf_range(-PI, PI))
	var src := b._source as RandomInput
	if src:
		src.sync_yaw(b.yaw)
	respawns += 1
	_per[i]["anchor"] = at
	_per[i]["anchor_tick"] = ticks
	_per[i]["asking"] = 0
	_per[i]["last"] = at
	_per[i]["since_respawn"] = 0
	_per[i]["embedded"] = false


func _event(kind: String, body_index: int, pos: Vector3, more: Dictionary) -> void:
	if events.size() < MAX_EVENTS:
		var e := {"kind": kind, "tick": ticks, "body": body_index, "pos": [pos.x, pos.y, pos.z]}
		e.merge(more)
		events.append(e)


func report() -> Dictionary:
	var tps := float(Engine.physics_ticks_per_second)
	var inputs := []
	for b in bodies:
		var src := b._source as RandomInput
		if src:
			inputs.append({"segments": src.segments, "sprints": src.sprints,
				"sprints_cut_short": src.sprints_cut_short, "jump_presses": src.jumps})
	var region_seconds := {}
	for k in regions:
		region_seconds[k] = snappedf(regions[k] / tps, 0.01)
	var falls := below_kill_plane + embedded_in_static
	return {
		"instrument": "fuzz", "seed": seed_value, "bodies": bodies.size(),
		"ticks": ticks, "seconds": ticks / tps,
		"falls_through_world": falls, "below_kill_plane": below_kill_plane, "embedded_in_static": embedded_in_static,
		"stuck_states": stuck_states, "non_finite": non_finite,
		"three_zeros": falls == 0 and stuck_states == 0 and non_finite == 0,
		"expected_pit_falls": expected_falls, "respawns": respawns, "respawn_every_s": respawn_every_ticks / tps,
		"events": events, "events_truncated": (falls + stuck_states + non_finite) > events.size(),
		"body_events": counts, "distance_m": distance, "max_speed_m_s": max_speed,
		"max_landing_speed_m_s": max_fall_speed, "max_height_m": max_height,
		"region_seconds": region_seconds, "regions_visited": regions.size(),
		"regions_total": course.data.get("regions", []).size(), "input": inputs,
		"definitions": {"stuck": "has not left a 1 cm ball for 3 s (360 ticks) while input asked for movement on every one of those ticks",
			"fall_through_world": "below kill_plane_y, or the body's shape shrunk by 5 cm overlaps a static body",
			"non_finite": "NaN or infinity in position, velocity, yaw or pitch"},
	}
