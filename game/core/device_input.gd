class_name DeviceInput
extends InputSource
## Reads the engine's input map. All input goes through named actions, so
## keyboard, mouse, trackpad and gamepad all work and nothing is bound to the
## Super key (window rules).

## Actions sampled each tick; movement adds its own on start-up.
static var actions: PackedStringArray = []
var _look := Vector2.ZERO


func add_look(delta: Vector2) -> void:
	_look += delta


func sample(_tick: int) -> Dictionary:
	var d := {}
	for a in actions:
		d[a] = Input.get_action_strength(a)
	d["look_x"] = _look.x
	d["look_y"] = _look.y
	_look = Vector2.ZERO
	return d
