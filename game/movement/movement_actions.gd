class_name MovementActions
extends RefCounted
## The movement module's input actions and their default bindings, added to
## the engine's input map on start-up unless a saved remap already set them.
## Keys are physical positions (WASD wherever the layout puts the letters).
## Nothing is bound to the Super key (window rules).

const MOVE_FORWARD := "move_forward"
const MOVE_BACK := "move_back"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const JUMP := "jump"
const LOOK_LEFT := "look_left"
const LOOK_RIGHT := "look_right"
const LOOK_UP := "look_up"
const LOOK_DOWN := "look_down"
const ALL: PackedStringArray = [MOVE_FORWARD, MOVE_BACK, MOVE_LEFT, MOVE_RIGHT, JUMP,
	LOOK_LEFT, LOOK_RIGHT, LOOK_UP, LOOK_DOWN]
## Per-axis dead zone; the body applies the round one (decision input-latency).
const AXIS_DEAD_ZONE := 0.15


static func ensure() -> void:
	_add(MOVE_FORWARD, [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add(MOVE_BACK, [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add(MOVE_LEFT, [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(MOVE_RIGHT, [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(JUMP, [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_add(LOOK_LEFT, [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add(LOOK_RIGHT, [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add(LOOK_UP, [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add(LOOK_DOWN, [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	for a in ALL:
		if not DeviceInput.actions.has(a):
			DeviceInput.actions.append(a)


static func _add(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, AXIS_DEAD_ZONE)
	if InputMap.action_get_events(action).is_empty():
		for e in events:
			InputMap.action_add_event(action, e)


static func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


static func _button(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = b
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e
