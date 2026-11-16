extends Node3D
## The movement module's fixture scene. A preset's `fixture` block says which
## course to build, which bodies to put on it and what drives them, and which
## instrument watches. It ships in exported builds so the benchmark mode can
## run the same presets on another machine.
##
## fixture: {
##   "course": "docs/fixtures/metrics-course.json",   (repo-relative or res://)
##   "mode": "run" | "fuzz" | "metrics" | "jump_proof",
##   "players": [{"input": "device" | "random" | "script" | "manual" | "none",
##                "spawn": "apron-gaps" or [x, y, z], "yaw_deg": 0, "seed": 1,
##                "ghost": false, "events": [...]}],
##   "run_ticks": 1200,          (mode run: the end state is taken at this tick)
##   "cuts": [{"tick": 600, "player": 0, "spawn": "stairs-deck", "yaw_deg": 0}],
##                               (mode run: put a body somewhere at a tick, to show
##                                several pieces of the course in one run)
##   "jump_proof": {"gravity_m_s2": 10, "cases": [...]},   (the known answers)
##   "poison": {"tick": 600, "player": 0},   (mode fuzz: put a NaN in a body's
##                               velocity after its move at that tick; the known
##                               answer for the non-finite check)
##   "tuning": {"jump_height": 1.25, ...},
##   "fuzz": {"seed": 7, "respawn_every_s": 20, "seconds": 600},
##                               (the run ends after that much simulated time)
##   "metrics": {"only": ["flat", "gap"]},
##   "camera": {"mode": "chase" | "first" | "side" | "top", "player": 0},
##   "light": {"shadows": true, "shadow_distance": 60, "grid": true}
## }

const HarnessCamera := preload("res://movement/fixtures/harness_camera.gd")

var course: MetricsCourse
var bodies: Array[PlayerBody] = []
var slots: Array[PlayerSlot] = []
var mode := "run"
var run_ticks := 0
var fuzz: FuzzProbe
var metrics: MetricsProbe
var _end_state: Dictionary = {}
var _cfg: Dictionary = {}
var _event_counts: Array = []
## What a tick of this scene costs the processor: wall time from the first
## script to run in the tick to the last (every body's move and the
## instruments that watch them), in microseconds.
var _tick_usec_sum := 0
var _tick_usec_max := 0
var _tick_count := 0
var _tick_started := 0


func configure_fixture(cfg: Dictionary) -> void:
	_cfg = cfg
	mode = String(cfg.get("mode", "run"))
	run_ticks = int(cfg.get("run_ticks", 0))
	_make_sky(cfg.get("light", {}))
	course = MetricsCourse.new()
	course.name = "Course"
	course.grid = bool(cfg.get("light", {}).get("grid", true))
	add_child(course)
	course.build(MetricsCourse.load_data(_resolve(String(cfg.get("course", "")))))
	var tuning := MovementTuning.new()
	for k in cfg.get("tuning", {}):
		if k in tuning:
			tuning.set(k, cfg["tuning"][k])
		else:
			push_error("movement fixture: no tuning value named %s" % k)
	var manual: ManualInput = null
	for p in cfg.get("players", []):
		var src: InputSource = null
		match String(p.get("input", "none")):
			"device":
				MovementActions.ensure()
				var dev := DeviceInput.new()
				var feeder := LookFeeder.new(dev)
				feeder.require_capture = false
				add_child(feeder)
				src = dev
			"random":
				src = RandomInput.new(int(p.get("seed", 1)))
			"script":
				src = ScriptInput.new(p.get("events", []))
			"manual":
				manual = ManualInput.new()
				src = manual
		var slot := Players.add(src, {}, bool(p.get("ghost", false)))
		var sp := course.spawn_point(p.get("spawn", [0, 0, 0]))
		var yaw: float = sp["yaw"] + deg_to_rad(float(p.get("yaw_deg", 0.0)))
		var b := PlayerBody.spawn(slot, self, sp["pos"] + Vector3(0, 0.02, 0), yaw, tuning)
		if src is RandomInput:
			(src as RandomInput).sync_yaw(yaw)
		slots.append(slot)
		bodies.append(b)
		var c := {"jumped": 0, "landed": 0, "left_ground": 0}
		_event_counts.append(c)
		b.jumped.connect(func(): c["jumped"] += 1)
		b.landed.connect(func(_s: float): c["landed"] += 1)
		b.left_ground.connect(func(): c["left_ground"] += 1)
	match mode:
		"fuzz":
			fuzz = FuzzProbe.new()
			fuzz.name = "FuzzProbe"
			var f: Dictionary = cfg.get("fuzz", {})
			fuzz.setup(course, bodies, int(f.get("seed", 1)),
				int(float(f.get("respawn_every_s", 0.0)) * Engine.physics_ticks_per_second))
			add_child(fuzz)
			if cfg.has("poison"):
				# After the bodies' move and before the probe looks, so the bad
				# value is seen and never reaches the physics engine.
				var poison := Poison.new()
				poison.body = bodies[clampi(int(cfg["poison"].get("player", 0)), 0, bodies.size() - 1)]
				poison.at_tick = int(cfg["poison"].get("tick", 600))
				poison.clock = course.clock
				add_child(poison)
		"metrics", "jump_proof":
			if manual == null or bodies.is_empty():
				push_error("movement fixture: mode %s needs a player with input \"manual\"" % mode)
			else:
				metrics = MetricsProbe.new()
				metrics.name = "MetricsProbe"
				metrics.only_kinds = PackedStringArray(cfg.get("metrics", {}).get("only", []))
				metrics.known = cfg.get("jump_proof", {})
				metrics.setup(course, bodies[0], manual, mode)
				add_child(metrics)
				metrics.start()
	var first := TickMark.new()
	first.process_physics_priority = -999
	first.hit = func(): _tick_started = Time.get_ticks_usec()
	add_child(first)
	var last := TickMark.new()
	last.process_physics_priority = 4000
	last.hit = func():
		var took := Time.get_ticks_usec() - _tick_started
		_tick_usec_sum += took
		_tick_usec_max = maxi(_tick_usec_max, took)
		_tick_count += 1
	add_child(last)
	var cam_cfg: Dictionary = cfg.get("camera", {})
	if not cam_cfg.is_empty() and not bodies.is_empty():
		var cam := HarnessCamera.new()
		cam.name = "HarnessCamera"
		cam.body = bodies[clampi(int(cam_cfg.get("player", 0)), 0, bodies.size() - 1)]
		cam.mode = String(cam_cfg.get("mode", "chase"))
		cam.fov = float(cam_cfg.get("fov", 75.0))
		cam.far = 600.0
		cam.distance = float(cam_cfg.get("distance", cam.distance))
		cam.height = float(cam_cfg.get("height", cam.height))
		if cam_cfg.has("offset"):
			cam.offset = MetricsCourse._v3(cam_cfg["offset"])
		add_child(cam)
		cam.current = true


func _exit_tree() -> void:
	for s in slots:
		Players.remove(s)


func _physics_process(_delta: float) -> void:
	if mode != "run" or course == null:
		return
	# This node runs before its bodies in the tick, so a cut at tick N is in
	# place before the bodies' N-th move (the clock has already counted it).
	for cut in _cfg.get("cuts", []):
		if int(cut["tick"]) == course.clock.tick:
			var sp := course.spawn_point(cut.get("spawn", [0, 0, 0]))
			var b := bodies[clampi(int(cut.get("player", 0)), 0, bodies.size() - 1)]
			b.teleport(sp["pos"] + Vector3(0, 0.02, 0), sp["yaw"] + deg_to_rad(float(cut.get("yaw_deg", 0.0))))
	if run_ticks > 0 and _end_state.is_empty() and course.clock.tick > run_ticks:
		_end_state = _state()


## The body a latency probe should watch.
func latency_target() -> Node3D:
	return bodies[0] if not bodies.is_empty() else null


## Put the watched body back at its spawn (the latency probe calls this
## every so often so the body doesn't walk off the course).
func latency_reset() -> void:
	if bodies.is_empty():
		return
	var p: Dictionary = _cfg.get("players", [{}])[0]
	var sp := course.spawn_point(p.get("spawn", [0, 0, 0]))
	bodies[0].teleport(sp["pos"] + Vector3(0, 0.02, 0), sp["yaw"] + deg_to_rad(float(p.get("yaw_deg", 0.0))))


func verify_finished() -> bool:
	match mode:
		"metrics", "jump_proof":
			return metrics != null and metrics.finished
		"run":
			return run_ticks > 0 and not _end_state.is_empty()
		"fuzz":
			var want := float(_cfg.get("fuzz", {}).get("seconds", 0.0))
			return fuzz != null and want > 0.0 and fuzz.ticks >= int(want * Engine.physics_ticks_per_second)
	return false


func verify_report() -> Dictionary:
	var rep := {"fixture": "movement", "mode": mode, "course": course.data.get("id", "") if course else "",
		"players": bodies.size(), "player_slots": Players.slots.size(),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"tick_cost_ms": {"mean": _tick_usec_sum / 1000.0 / maxi(_tick_count, 1), "max": _tick_usec_max / 1000.0,
			"ticks": _tick_count, "what": "wall time of one tick's scripts: every body's move and the instruments watching them"},
		"world_tick": course.clock.tick if course else 0}
	if fuzz:
		rep["fuzz"] = fuzz.report()
	if metrics:
		rep["metrics"] = metrics.results
		rep["finished"] = metrics.finished
	if mode == "run":
		rep["end_state"] = _end_state if not _end_state.is_empty() else _state()
		rep["end_state_at_run_ticks"] = not _end_state.is_empty()
	return rep


func _state() -> Dictionary:
	var list := []
	var raw := []
	for i in bodies.size():
		var b := bodies[i]
		list.append({"player_id": b.player_id, "ghost": b.is_ghost, "tick": b.tick,
			"position": [b.global_position.x, b.global_position.y, b.global_position.z],
			"velocity": [b.velocity.x, b.velocity.y, b.velocity.z], "yaw": b.yaw, "pitch": b.pitch,
			"state": PlayerBody.State.keys()[b.state], "events": _event_counts[i].duplicate(),
			"finite": b.global_position.is_finite() and b.velocity.is_finite()})
		raw.append([b.global_position, b.velocity, b.yaw, b.pitch, b.tick, b.state])
	return {"world_tick": course.clock.tick, "bodies": list,
		"hash": var_to_bytes(raw).hex_encode().sha256_text()}


class TickMark:
	extends Node
	var hit: Callable

	func _physics_process(_delta: float) -> void:
		hit.call()


class Poison:
	extends Node
	var body: PlayerBody
	var clock: WorldClock
	var at_tick := 600

	func _init() -> void:
		process_physics_priority = 500

	func _physics_process(_delta: float) -> void:
		if clock.tick == at_tick:
			body.velocity = Vector3(NAN, 0.0, 0.0)


func _resolve(path: String) -> String:
	var v := get_node_or_null("/root/Verify")
	if v and v.has_method("resolve_path"):
		return v.resolve_path(path)
	return path


func _make_sky(light: Dictionary) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.shadow_enabled = bool(light.get("shadows", true))
	# The course is watched from a few metres; shadows further off are not seen.
	sun.directional_shadow_max_distance = float(light.get("shadow_distance", 60.0))
	add_child(sun)
