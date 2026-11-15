class_name InputDefaults
extends RefCounted
## Default bindings for core's actions, added to the engine's input map at
## start-up if a saved remap hasn't already set them. Nothing is ever bound to
## the Super/Meta key (window rules); verify checks that.

static func ensure() -> void:
	_add("pause", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])
	_add("toggle_fullscreen", [_key(KEY_F11)])


static func _add(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		for e in events:
			InputMap.action_add_event(action, e)


static func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


static func _joy(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


## Every event bound to the Meta (Super) key, for the window-rules check.
static func super_bindings() -> Array:
	var out := []
	for a in InputMap.get_actions():
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and (e.meta_pressed or e.physical_keycode == KEY_META or e.keycode == KEY_META):
				out.append({"action": a, "event": e.as_text()})
	return out
