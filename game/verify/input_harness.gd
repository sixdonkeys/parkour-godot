extends Node
## Input harness (added with `movement`): plays an input script through the
## engine's input map. Each entry becomes a real InputEvent (a key, a gamepad
## axis or button, a pointer move) handed to Input.parse_input_event, so the
## game receives it exactly as it would from a device: `_input` runs, action
## states change, and whatever reads the input map sees it.
##
## Entries are keyed by physics tick, counted from the tick after the harness
## enters the scene, and are delivered before anything else in that tick
## runs. So the same script gives the same simulation in test mode (two
## ticks per frame) and in a normal launch (ticks follow the clock).
##
## Format `input-script/1` (docs/fixtures/README.md):
##   {"format": "input-script/1", "events": [
##     {"tick": 60,  "key": "W", "pressed": true},
##     {"tick": 300, "key": "Space", "pressed": true},
##     {"tick": 120, "joy_axis": "left_y", "value": -1.0},
##     {"tick": 200, "joy_button": "a", "pressed": true},
##     {"tick": 240, "mouse": [35, 0]}]}

const AXES := {"left_x": JOY_AXIS_LEFT_X, "left_y": JOY_AXIS_LEFT_Y, "right_x": JOY_AXIS_RIGHT_X,
	"right_y": JOY_AXIS_RIGHT_Y, "trigger_left": JOY_AXIS_TRIGGER_LEFT, "trigger_right": JOY_AXIS_TRIGGER_RIGHT}
const BUTTONS := {"a": JOY_BUTTON_A, "b": JOY_BUTTON_B, "x": JOY_BUTTON_X, "y": JOY_BUTTON_Y,
	"start": JOY_BUTTON_START, "left_shoulder": JOY_BUTTON_LEFT_SHOULDER, "right_shoulder": JOY_BUTTON_RIGHT_SHOULDER}

var tick := 0
var delivered := 0
var skipped: Array = []
var _events: Array = []
var _next := 0


func _init() -> void:
	process_physics_priority = -900
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(script: Dictionary) -> bool:
	if script.get("format", "") != "input-script/1":
		push_error("verify: input script is not input-script/1")
		return false
	_events = script.get("events", []).duplicate(true)
	_events.sort_custom(func(a, b): return int(a["tick"]) < int(b["tick"]))
	return true


func _physics_process(_delta: float) -> void:
	tick += 1
	var any := false
	while _next < _events.size() and int(_events[_next]["tick"]) <= tick:
		var ev := make_event(_events[_next])
		if ev:
			Input.parse_input_event(ev)
			delivered += 1
			any = true
		else:
			skipped.append(_events[_next])
		_next += 1
	if any:
		# Hand them over now, before this tick's bodies sample their input.
		Input.flush_buffered_events()


func finished() -> bool:
	return _next >= _events.size()


func report() -> Dictionary:
	return {"format": "input-script/1", "events": _events.size(), "delivered": delivered, "skipped": skipped,
		"last_tick": int(_events[-1]["tick"]) if not _events.is_empty() else 0, "ticks_run": tick}


## One script entry as a real input event, or null if it names nothing known.
static func make_event(e: Dictionary) -> InputEvent:
	if e.has("key"):
		var code := OS.find_keycode_from_string(String(e["key"]))
		if code == KEY_NONE:
			return null
		var k := InputEventKey.new()
		k.physical_keycode = code
		k.keycode = code
		k.pressed = bool(e.get("pressed", true))
		return k
	if e.has("joy_axis"):
		if not AXES.has(e["joy_axis"]):
			return null
		var m := InputEventJoypadMotion.new()
		m.axis = AXES[e["joy_axis"]]
		m.axis_value = float(e.get("value", 0.0))
		return m
	if e.has("joy_button"):
		if not BUTTONS.has(e["joy_button"]):
			return null
		var b := InputEventJoypadButton.new()
		b.button_index = BUTTONS[e["joy_button"]]
		b.pressed = bool(e.get("pressed", true))
		b.pressure = 1.0 if b.pressed else 0.0
		return b
	if e.has("mouse"):
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(float(e["mouse"][0]), float(e["mouse"][1]))
		mm.screen_relative = mm.relative
		return mm
	return null
