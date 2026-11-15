class_name MetricsProbe
extends Node
## The movement-numbers instrument. Drives one body down the metrics
## course's lanes with a test-pilot input source and reports how fast, how
## far and how high it goes: top speed and how long it takes to get there,
## the jump at a full sprint, and for each family of stepped pieces (gaps,
## ledges, steps, slopes) the largest that succeeds and the first that fails.
##
## In `jump_proof` mode it instead launches the body at known speeds under a
## known gravity and compares what it measures with arithmetic; that is the
## instrument's known-answer proof.

var course: MetricsCourse
var body: PlayerBody
var input: ManualInput
var mode := "metrics"
var results: Dictionary = {}
var finished := false
## Only these lane kinds are run (empty = all), to keep a quick check quick.
var only_kinds: PackedStringArray = []
## jump_proof mode: {"gravity_m_s2": 10.0, "cases": [{"launch": [x, y, z],
## "apex_m": .., "airtime_s": .., "distance_m": ..}]}, the known answers,
## written out in the fixture file.
var known: Dictionary = {}

var _jumped_tick := -1
var _left_tick := -1
var _landed_tick := -1
var _landed_speed := 0.0
var _dt := 1.0 / 120.0


func setup(p_course: MetricsCourse, p_body: PlayerBody, p_input: ManualInput, p_mode: String) -> void:
	course = p_course
	body = p_body
	input = p_input
	mode = p_mode
	_dt = 1.0 / Engine.physics_ticks_per_second
	body.jumped.connect(func(): _jumped_tick = body.tick)
	body.left_ground.connect(func(): _left_tick = body.tick)
	body.landed.connect(func(speed: float):
		_landed_tick = body.tick
		_landed_speed = speed)


func start() -> void:
	_run.call_deferred()


func _run() -> void:
	if mode == "jump_proof":
		await _jump_proof()
	else:
		await _metrics()
	finished = true


func _tick() -> void:
	await get_tree().physics_frame


func _wants(kind: String) -> bool:
	return only_kinds.is_empty() or only_kinds.has(kind)


## Put the body down and wait until it stands still on the ground.
func _place(at: Vector3, yaw: float) -> void:
	input.release()
	body.teleport(at + Vector3(0, 0.02, 0), yaw)
	_jumped_tick = -1
	_left_tick = -1
	_landed_tick = -1
	for i in 240:
		await _tick()
		if body.state == PlayerBody.State.GROUNDED and i >= 12:
			break


# --- known-answer proof ---------------------------------------------------------

func _jump_proof() -> void:
	var g := float(known.get("gravity_m_s2", 10.0))
	results = {"instrument": "movement numbers: jump", "gravity_m_s2": g,
		"body_fall_gravity_m_s2": body.tuning.fall_gravity(), "body_rise_gravity_m_s2": body.tuning.rise_gravity(),
		"tick_s": _dt, "cases": []}
	var all_ok: bool = not known.get("cases", []).is_empty()
	for case in known.get("cases", []):
		var v := MetricsCourse._v3(case["launch"])
		await _place(Vector3(53, 0, 0), 0.0)
		var from := body.global_position
		var t0 := body.tick
		var apex := 0.0
		body.launch(v)
		for i in 2400:
			await _tick()
			apex = maxf(apex, body.global_position.y - from.y)
			if _landed_tick > t0:
				break
		var air_ticks := _landed_tick - t0
		var to := body.global_position
		var vh := Vector2(v.x, v.z).length()
		var expected := {"apex_m": float(case["apex_m"]), "airtime_s": float(case["airtime_s"]),
			"distance_m": float(case["distance_m"]), "landing_speed_m_s": v.y}
		var measured := {"apex_m": apex, "airtime_s": air_ticks * _dt, "airtime_ticks": air_ticks,
			"distance_m": Vector2(to.x - from.x, to.z - from.z).length(), "landing_speed_m_s": _landed_speed}
		var tolerance := {"apex_m": 0.003, "airtime_s": _dt * 1.01, "distance_m": vh * _dt + 0.003,
			"landing_speed_m_s": g * _dt}
		var ok := _landed_tick > t0
		for k in tolerance:
			ok = ok and absf(float(measured[k]) - float(expected[k])) <= float(tolerance[k])
		all_ok = all_ok and ok
		results["cases"].append({"launch_m_s": [v.x, v.y, v.z], "expected": expected, "measured": measured,
			"tolerance": tolerance, "pass": ok})
	results["pass"] = all_ok


# --- the measurements --------------------------------------------------------------

func _metrics() -> void:
	var t := body.tuning
	results = {"instrument": "movement numbers", "tuning": t.describe(), "lanes": {}}
	if _wants("flat"):
		results["sprint"] = await _sprint_and_jump()
		results["standing_jump"] = await _standing_jump(true, 120)
		results["standing_vertical"] = await _standing_jump(false, 120)
		results["tap_hop"] = await _standing_jump(false, 1)
		results["turn_90"] = await _turn_90()
		results["air_steer"] = await _air_steer()
	var families := {"gap": [], "gap_late": [], "ledge": [], "step": [], "slope": []}
	for l in course.data.get("lanes", []):
		var kind := String(l["kind"])
		if not _wants(kind):
			continue
		match kind:
			"gap":
				var edge: Dictionary = await _gap(l, false)
				var late: Dictionary = await _gap(l, true)
				results["lanes"][l["id"]] = {"edge_take_off": edge, "last_tick_take_off": late}
				families["gap"].append([float(l["value"]), edge["cleared"]])
				families["gap_late"].append([float(l["value"]), late["cleared"]])
			"ledge":
				var r: Dictionary = await _ledge(l)
				results["lanes"][l["id"]] = r
				families["ledge"].append([float(l["value"]), r["cleared"]])
			"step", "stairs":
				var r2: Dictionary = await _walk_up(l, 4.0)
				results["lanes"][l["id"]] = r2
				if kind == "step":
					families["step"].append([float(l["value"]), r2["cleared"]])
			"slope":
				var r3: Dictionary = await _walk_up(l, 9.0)
				results["lanes"][l["id"]] = r3
				families["slope"].append([float(l["value"]), r3["cleared"]])
			"carry":
				results["lanes"][l["id"]] = await _carry(l)
	var summary := {}
	for k in families:
		if not families[k].is_empty():
			summary[k] = _largest_and_first(families[k])
	results["stepped"] = summary
	if results.has("sprint"):
		var s: Dictionary = results["sprint"]
		results["numbers"] = {
			"top_speed_m_s": s["top_speed_m_s"],
			"time_to_top_speed_s": s["time_to_top_speed_s"],
			"longest_jump_at_full_sprint_m": s["jump"]["distance_m"],
			"jump_height_m": s["jump"]["apex_m"],
			"jump_airtime_s": s["jump"]["airtime_s"],
			"standing_jump_m": results["standing_jump"]["distance_m"],
			"note": "ledge reach and wall run are traversal's; docs/metrics.json is written when traversal closes",
		}
	input.release()


## From stepped results [[size, cleared], ...]: the largest that succeeded
## and the first (smallest) that failed.
static func _largest_and_first(rows: Array) -> Dictionary:
	var largest = null
	var first_fail = null
	for row in rows:
		if row[1] and (largest == null or row[0] > largest):
			largest = row[0]
		if not row[1] and (first_fail == null or row[0] < first_fail):
			first_fail = row[0]
	return {"largest_cleared": largest, "first_failed": first_fail,
		"monotonic": largest == null or first_fail == null or largest < first_fail, "results": rows}


func _h(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Press jump (already standing or running), follow the body through the
## air and return what the jump did.
func _measure_jump(hold_ticks: int, max_wait := 30) -> Dictionary:
	var before := body.tick
	input.jump = true
	var waited := 0
	while _jumped_tick <= before and waited < max_wait:
		await _tick()
		waited += 1
	if _jumped_tick <= before:
		input.jump = false
		return {"jumped": false}
	var off := body.global_position
	# The body has already made the first tick's move; step back to the take-off point.
	var t_off := _jumped_tick
	var start := off - body.get_position_delta()
	var speed_off := _h(body.velocity).length()
	var apex := 0.0
	var held := 1
	for i in 1200:
		apex = maxf(apex, body.global_position.y - start.y)
		if held >= hold_ticks:
			input.jump = false
		if _landed_tick >= t_off:
			break
		await _tick()
		held += 1
	input.jump = false
	var land := body.global_position
	var air := _landed_tick - t_off + 1
	return {"jumped": true, "distance_m": _h(land - start).length(), "apex_m": apex, "airtime_s": air * _dt,
		"airtime_ticks": air, "take_off": [start.x, start.y, start.z], "landing": [land.x, land.y, land.z],
		"speed_at_take_off_m_s": speed_off, "landing_speed_m_s": _landed_speed,
		"speed_after_landing_m_s": _h(body.velocity).length()}


func _sprint_and_jump() -> Dictionary:
	var l := course.lane("flat")
	var t := body.tuning
	await _place(MetricsCourse._v3(l["start"]), 0.0)
	var from := body.global_position
	var t0 := body.tick
	input.forward = 1.0
	var marks := {}
	var first_tick_move := 0.0
	var jump_z := float(l["jump_z"])
	var top := 0.0
	while body.global_position.z > jump_z:
		await _tick()
		var sp := _h(body.velocity).length()
		var n := body.tick - t0
		if n == 1:
			first_tick_move = _h(body.global_position - from).length()
		for mark in [["run_speed", t.run_speed], ["70_percent", 0.7 * t.top_speed], ["top_speed", 0.999 * t.top_speed]]:
			if not marks.has(mark[0]) and sp >= float(mark[1]) - 1e-4:
				marks[mark[0]] = {"s": n * _dt, "m": _h(body.global_position - from).length()}
		top = maxf(top, sp)
		if n > 2400:
			break
	var jump: Dictionary = await _measure_jump(120)
	# Let it run on, then let go and measure the stop.
	for i in 30:
		await _tick()
	var speed_before_stop := _h(body.velocity).length()
	var p0 := body.global_position
	var n0 := body.tick
	input.forward = 0.0
	while _h(body.velocity).length() > 0.01 and body.tick - n0 < 600:
		await _tick()
	return {"top_speed_m_s": top, "first_tick_movement_m": first_tick_move,
		"time_to_run_speed_s": marks.get("run_speed", {}).get("s"),
		"time_to_70_percent_s": marks.get("70_percent", {}).get("s"),
		"time_to_top_speed_s": marks.get("top_speed", {}).get("s"),
		"distance_to_top_speed_m": marks.get("top_speed", {}).get("m"),
		"jump": jump, "speed_kept_through_jump": jump.get("speed_after_landing_m_s", 0.0) / maxf(jump.get("speed_at_take_off_m_s", 1.0), 0.001),
		"stop": {"from_m_s": speed_before_stop, "seconds": (body.tick - n0) * _dt,
			"metres": _h(body.global_position - p0).length()}}


func _standing_jump(forward: bool, hold_ticks: int) -> Dictionary:
	await _place(Vector3(53, 0, 0), 0.0)
	input.forward = 1.0 if forward else 0.0
	var r: Dictionary = await _measure_jump(hold_ticks)
	input.release()
	return r


## At full speed, turn the facing 90 degrees in one tick and keep holding
## forward: how much speed the turn costs and how long it takes.
func _turn_90() -> Dictionary:
	await _place(Vector3(58, 0, 2), -PI / 2)
	input.forward = 1.0
	while body.global_position.x < 90.0 and body.tick < 1000000:
		await _tick()
		if body.horizontal_speed() >= 0.999 * body.tuning.top_speed:
			break
	var before := body.horizontal_speed()
	var at := body.global_position
	input.look_once = -PI / 2
	var lowest := before
	var ticks := 0
	var aligned := -1
	for i in 240:
		await _tick()
		ticks += 1
		var v := _h(body.velocity)
		lowest = minf(lowest, v.length())
		# New facing is -Z.
		if aligned < 0 and v.length() > 0.1 and v.normalized().dot(Vector2(0, -1)) > cos(deg_to_rad(2.0)):
			aligned = ticks
			break
	var turned_at := body.global_position
	input.release()
	return {"speed_before_m_s": before, "lowest_speed_m_s": lowest, "speed_kept": lowest / maxf(before, 0.001),
		"seconds_to_new_heading": aligned * _dt if aligned > 0 else null,
		"overshoot_m": absf(turned_at.x - at.x)}


## Jump at full speed and turn the facing 90 degrees at take-off while
## holding forward: how far air steering bends the jump.
func _air_steer() -> Dictionary:
	var l := course.lane("flat")
	await _place(MetricsCourse._v3(l["start"]), 0.0)
	input.forward = 1.0
	while body.global_position.z > -30.0:
		await _tick()
	var before := body.tick
	input.jump = true
	while _jumped_tick <= before:
		await _tick()
	var v0 := _h(body.velocity)
	var x0 := body.global_position.x
	input.look_once = PI / 2
	while _landed_tick < _jumped_tick:
		await _tick()
	var v1 := _h(body.velocity)
	input.release()
	return {"heading_change_deg": rad_to_deg(absf(v0.angle_to(v1))), "sideways_m": absf(body.global_position.x - x0),
		"speed_at_take_off_m_s": v0.length(), "speed_at_landing_m_s": v1.length()}


func _gap(l: Dictionary, late: bool) -> Dictionary:
	await _place(MetricsCourse._v3(l["start"]), 0.0)
	input.forward = 1.0
	var edge := float(l["edge_z"])
	var far := float(l["far_z"])
	var n0 := body.tick
	var pressed := false
	var take_off = null
	var speed := 0.0
	var out := {"cleared": false, "policy": "last tick the jump still works (coyote time)" if late else "jump as the body's centre reaches the edge"}
	while body.tick - n0 < 2400:
		await _tick()
		var p := body.global_position
		if not pressed:
			var go := false
			if late:
				go = _left_tick > n0 and body.tick - _left_tick >= body.tuning.coyote_ticks - 2
			else:
				go = p.z <= edge + 0.1
			if go:
				pressed = true
				input.jump = true
				take_off = p
				speed = body.horizontal_speed()
		if p.y < -1.0:
			out["fell_at_z"] = p.z
			break
		if pressed and _landed_tick > _jumped_tick and _jumped_tick > n0 and p.y > -0.05:
			out["cleared"] = p.z <= far + body.tuning.radius + 0.01
			out["landing_z"] = p.z
			out["past_far_edge_m"] = far - p.z
			break
	input.release()
	if take_off != null:
		out["take_off_z"] = take_off.z
		out["take_off_past_edge_m"] = edge - take_off.z
		out["speed_m_s"] = speed
	return out


func _ledge(l: Dictionary) -> Dictionary:
	await _place(MetricsCourse._v3(l["start"]), 0.0)
	input.forward = 1.0
	var face := float(l["face_z"])
	var top := float(l["top_y"])
	var n0 := body.tick
	var pressed := false
	var out := {"cleared": false}
	while body.tick - n0 < 1200:
		await _tick()
		var p := body.global_position
		var gap := p.z - face - body.tuning.radius
		if not pressed and gap <= body.horizontal_speed() * body.tuning.time_to_peak:
			pressed = true
			input.jump = true
			out["jumped_from_m"] = gap
			out["speed_m_s"] = body.horizontal_speed()
		if pressed and body.state == PlayerBody.State.GROUNDED and p.y >= top - 0.02 and _landed_tick > _jumped_tick:
			out["cleared"] = true
			out["speed_on_top_m_s"] = body.horizontal_speed()
			break
		if pressed and _jumped_tick > n0 and body.tick - _jumped_tick > 240:
			break
	input.release()
	return out


## Walk (no jump) up a step, a staircase or a slope.
func _walk_up(l: Dictionary, timeout_s: float) -> Dictionary:
	await _place(MetricsCourse._v3(l["start"]), 0.0)
	input.forward = 1.0
	var face := float(l["face_z"])
	var top := float(l["top_y"])
	var n0 := body.tick
	var speed_in := 0.0
	var lowest := INF
	var reached := -1
	var out := {"cleared": false}
	while body.tick - n0 < int(timeout_s * Engine.physics_ticks_per_second) + 600:
		await _tick()
		var p := body.global_position
		if p.z > face + body.tuning.radius + 0.05:
			speed_in = body.horizontal_speed()
		elif reached < 0:
			reached = body.tick
		if reached >= 0:
			lowest = minf(lowest, body.get_real_velocity().length())
			if body.state == PlayerBody.State.GROUNDED and p.y >= top - 0.02:
				out["cleared"] = true
				out["seconds_on_piece"] = (body.tick - reached) * _dt
				break
			if body.tick - reached > int(timeout_s * Engine.physics_ticks_per_second):
				out["stopped_at_y"] = p.y
				break
	input.release()
	out["speed_in_m_s"] = speed_in
	out["lowest_speed_on_piece_m_s"] = lowest if lowest != INF else null
	out["speed_out_m_s"] = body.horizontal_speed()
	return out


## Stand on a moving surface for a whole cycle without input: the body must
## stay where it stood on the surface. Then jump at the surface's fastest
## moment: the body must keep the surface's speed.
func _carry(l: Dictionary) -> Dictionary:
	var mover: MovingSurface = course.movers.get(String(l["mover"]))
	if mover == null:
		return {"cleared": false, "error": "no mover"}
	# Start when the surface is at the start of its travel.
	while posmod(course.clock.tick + mover.phase_ticks, mover.period_ticks) != 0:
		await _tick()
	var half := MetricsCourse._v3(course.data["pieces"].filter(func(p): return p["id"] == l["mover"])[0]["size"]) * 0.5
	await _place(mover.global_position + Vector3(0, half.y, 0), 0.0)
	var rel0 := body.global_position - mover.global_position
	var drift := 0.0
	var lift := 0.0
	var grounded_all := true
	var w0 := course.clock.tick
	while course.clock.tick - w0 < mover.period_ticks:
		await _tick()
		var rel := body.global_position - mover.global_position - rel0
		drift = maxf(drift, _h(rel).length())
		lift = maxf(lift, absf(rel.y))
		grounded_all = grounded_all and body.state == PlayerBody.State.GROUNDED
	var out := {"horizontal_drift_m": drift, "vertical_gap_m": lift, "stayed_grounded": grounded_all,
		"cleared": drift <= 0.05 and lift <= 0.05 and grounded_all, "cycle_s": mover.period_ticks * _dt}
	# Quarter of a cycle later the surface is at its fastest.
	while posmod(course.clock.tick + mover.phase_ticks, mover.period_ticks) != mover.period_ticks / 4:
		await _tick()
	var surface_v := mover.velocity_at(course.clock.tick)
	var j: Dictionary = await _measure_jump(120)
	if j.get("jumped", false):
		out["surface_speed_m_s"] = surface_v.length()
		out["jump_carried_m"] = j["distance_m"]
		out["jump_carried_expected_m"] = _h(surface_v).length() * float(j["airtime_s"])
		out["jump_apex_m"] = j["apex_m"]
	input.release()
	return out
