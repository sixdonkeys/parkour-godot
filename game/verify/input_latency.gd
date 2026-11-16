extends Node
## Input-to-motion instrument (added with `movement`; decision input-latency).
##
## One trial: wait until the watched body is at rest; from a thread, at a
## seeded random moment inside a frame, hand the engine a real input event
## (Input.parse_input_event, as the operating system's event would arrive);
## then stamp
##   inject   when the event was handed to the engine,
##   input    when the engine delivered it to the game (`_input`),
##   tick     when the body's simulated position first changed,
##   motion   the frame_post_draw of the first frame whose drawn
##            (interpolated) position differs from where the body stood,
##   1 cm     the frame_post_draw of the first frame drawn 1 cm or more away.
## ARCHITECTURE.md defines the budget from `input` to `motion`. The log gives
## that and the longer inject-to-motion, and judges the 50 ms budget on the
## longer one. Only meaningful in real time (not --fixed-fps).
##
## preset: "input_latency": {"device": "key", "key": "W", "trials": 200, "seed": 1}
##         or {"device": "joy_axis", "axis": "left_y", "value": -1.0}
##         or {"device": "joy_button", "button": "a"}

const FrameStats := preload("res://verify/frame_stats.gd")
const InputHarness := preload("res://verify/input_harness.gd")
const BUDGET_MS := 50.0
const MOTION_EPS := 1e-6
const VISIBLE_M := 0.01

enum Phase { SETTLE, WAIT, RELEASE, DONE }

var target: Node3D
var scene: Node
var finished := false
var trials: Array = []
var failed := 0

var _params: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _phase := Phase.SETTLE
var _still := 0
var _last_pos := Vector3.INF
var _rest := Vector3.ZERO
var _rest_sim := Vector3.ZERO
var _thread: Thread
var _press: Dictionary = {}
var _release: Dictionary = {}
var _t_inject := 0
var _t_input := 0
var _t_tick := 0
var _t_motion := 0
var _t_visible := 0
var _armed_at := 0
var _seen_motion := false
var _seen_visible := false
var _frame_usec: PackedFloat64Array = []
var _last_frame := 0
var _want := 100
var _settle_frames := 20


func _init() -> void:
	process_physics_priority = 2000
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(p_scene: Node, params: Dictionary) -> void:
	scene = p_scene
	_params = params
	_want = int(params.get("trials", 100))
	_settle_frames = int(params.get("settle_frames", 20))
	_rng.seed = int(params.get("seed", 1))
	if scene.has_method("latency_target"):
		target = scene.latency_target()
	if target == null:
		push_error("verify: input_latency needs a scene with latency_target()")
		finished = true
		return
	match String(params.get("device", "key")):
		"key":
			_press = {"key": params.get("key", "W"), "pressed": true}
			_release = {"key": params.get("key", "W"), "pressed": false}
		"joy_axis":
			_press = {"joy_axis": params.get("axis", "left_y"), "value": float(params.get("value", -1.0))}
			_release = {"joy_axis": params.get("axis", "left_y"), "value": 0.0}
		"joy_button":
			_press = {"joy_button": params.get("button", "a"), "pressed": true}
			_release = {"joy_button": params.get("button", "a"), "pressed": false}
		_:
			push_error("verify: input_latency device %s unknown" % params.get("device"))
			finished = true
	RenderingServer.frame_post_draw.connect(_on_post_draw)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	if RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)


func _drawn_position() -> Vector3:
	return target.get_global_transform_interpolated().origin


func _process(_delta: float) -> void:
	if finished or target == null:
		return
	var pos := _drawn_position()
	match _phase:
		Phase.SETTLE:
			_still = _still + 1 if pos.is_equal_approx(_last_pos) and pos.distance_to(_last_pos) < MOTION_EPS else 0
			_last_pos = pos
			if _still >= _settle_frames:
				_arm(pos)
		Phase.WAIT:
			if _t_input > 0:
				var moved := pos.distance_to(_rest)
				if moved > MOTION_EPS:
					_seen_motion = true
				if moved >= VISIBLE_M:
					_seen_visible = true
			if Time.get_ticks_usec() - _armed_at > 1500000:
				failed += 1
				_phase = Phase.RELEASE
		Phase.RELEASE:
			_thread.wait_to_finish()
			var ev := InputHarness.make_event(_release)
			Input.parse_input_event(ev)
			Input.flush_buffered_events()
			if trials.size() + failed >= _want:
				finished = true
				_phase = Phase.DONE
			else:
				if scene.has_method("latency_reset") and (trials.size() + failed) % int(_params.get("reset_every", 20)) == 0:
					scene.latency_reset()
				_still = 0
				_last_pos = Vector3.INF
				_phase = Phase.SETTLE


func _arm(pos: Vector3) -> void:
	_rest = pos
	_rest_sim = target.global_position
	_t_inject = 0
	_t_input = 0
	_t_tick = 0
	_t_motion = 0
	_t_visible = 0
	_seen_motion = false
	_seen_visible = false
	_armed_at = Time.get_ticks_usec()
	# Anywhere inside the next two frames, so the event lands at every phase of a frame.
	var period := 16667.0
	if _frame_usec.size() >= 10:
		period = FrameStats.percentile(_frame_usec, 50) * 1000.0
	var delay := int(_rng.randf() * 2.0 * period)
	_thread = Thread.new()
	_thread.start(_inject.bind(delay, InputHarness.make_event(_press)))
	_phase = Phase.WAIT


func _inject(delay_usec: int, ev: InputEvent) -> void:
	OS.delay_usec(delay_usec)
	_t_inject = Time.get_ticks_usec()
	Input.parse_input_event(ev)


func _input(event: InputEvent) -> void:
	if _phase != Phase.WAIT or _t_input > 0:
		return
	var hit := false
	if event is InputEventKey and _press.has("key"):
		hit = event.pressed and not event.echo and event.physical_keycode == OS.find_keycode_from_string(String(_press["key"]))
	elif event is InputEventJoypadMotion and _press.has("joy_axis"):
		hit = event.axis == InputHarness.AXES[_press["joy_axis"]] and is_equal_approx(event.axis_value, float(_press["value"]))
	elif event is InputEventJoypadButton and _press.has("joy_button"):
		hit = event.pressed and event.button_index == InputHarness.BUTTONS[_press["joy_button"]]
	if hit:
		_t_input = Time.get_ticks_usec()


func _physics_process(_delta: float) -> void:
	if _phase == Phase.WAIT and _t_input > 0 and _t_tick == 0 and target.global_position.distance_to(_rest_sim) > MOTION_EPS:
		_t_tick = Time.get_ticks_usec()


func _on_post_draw() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame > 0:
		_frame_usec.append((now - _last_frame) / 1000.0)
	_last_frame = now
	if _phase != Phase.WAIT:
		return
	if _seen_motion and _t_motion == 0:
		_t_motion = now
	if _seen_visible and _t_visible == 0:
		_t_visible = now
		trials.append({
			"inject_to_input": (_t_input - _t_inject) / 1000.0,
			"input_to_tick": (_t_tick - _t_input) / 1000.0 if _t_tick > 0 else null,
			"input_to_motion": (_t_motion - _t_input) / 1000.0,
			"inject_to_motion": (_t_motion - _t_inject) / 1000.0,
			"input_to_1cm": (_t_visible - _t_input) / 1000.0,
			"inject_to_1cm": (_t_visible - _t_inject) / 1000.0,
		})
		_phase = Phase.RELEASE


func _series(key: String) -> PackedFloat64Array:
	var s := PackedFloat64Array()
	for t in trials:
		if t[key] != null:
			s.append(float(t[key]))
	return s


func _summary(key: String, with_series := false) -> Dictionary:
	var s := _series(key)
	var d := {"p50": FrameStats.percentile(s, 50), "p95": FrameStats.percentile(s, 95),
		"p99": FrameStats.percentile(s, 99), "min": FrameStats.percentile(s, 0), "max": FrameStats.percentile(s, 100)}
	if with_series:
		d["series_ms"] = s
		d["histogram"] = FrameStats.histogram(s, 2.0, 120.0)
	return d


func report() -> Dictionary:
	var judged := _summary("inject_to_motion", true)
	var defined := _summary("input_to_motion", true)
	var ok: bool = trials.size() > 0 and failed == 0 and float(judged["p95"]) <= BUDGET_MS
	return {
		"instrument": "input to motion", "device": _params.get("device", "key"), "event": _press,
		"trials": trials.size(), "trials_wanted": _want, "failed_trials": failed, "complete": finished,
		"frame_ms": {"p50": FrameStats.percentile(_frame_usec, 50), "p95": FrameStats.percentile(_frame_usec, 95),
			"p99": FrameStats.percentile(_frame_usec, 99), "max": FrameStats.percentile(_frame_usec, 100)},
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"vsync_mode": ["disabled", "enabled", "adaptive", "mailbox"][DisplayServer.window_get_vsync_mode()],
		"max_fps": Engine.max_fps, "physics_ticks_per_second": Engine.physics_ticks_per_second,
		"physics_interpolation": get_tree().physics_interpolation,
		"inject_to_first_motion_ms": judged,
		"input_to_first_motion_ms": defined,
		"inject_to_input_ms": _summary("inject_to_input"),
		"input_to_tick_ms": _summary("input_to_tick"),
		"input_to_1cm_ms": _summary("input_to_1cm"),
		"inject_to_1cm_ms": _summary("inject_to_1cm"),
		"budget": {"limit_ms": BUDGET_MS, "judged_on": "inject_to_first_motion_ms p95 (the longer of the two)",
			"p95_ms": judged["p95"], "defined_input_to_motion_p95_ms": defined["p95"], "pass": ok},
		"stamps": "Time.get_ticks_usec(): inject = before Input.parse_input_event on a thread; input = _input; tick = body position changed in _physics_process; motion = frame_post_draw of the first frame whose interpolated position differs",
	}
