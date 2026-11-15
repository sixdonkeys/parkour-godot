extends Node3D
## Known answer for the input-to-motion instrument: a block that jumps 10 cm
## a fixed time after the engine delivers a key press to `_input`, by the
## wall clock, and returns when the key is released. The instrument must
## read that delay, plus the wait for the next drawn frame and no more.
##
## fixture: {"delay_ms": 100, "key": "W"}

var delay_usec := 100000
var key := KEY_W
var _target: MeshInstance3D
var _t0 := 0
var _moved := false


func configure_fixture(cfg: Dictionary) -> void:
	delay_usec = int(float(cfg.get("delay_ms", 100.0)) * 1000.0)
	key = OS.find_keycode_from_string(String(cfg.get("key", "W")))


func _ready() -> void:
	_target = MeshInstance3D.new()
	_target.name = "Target"
	_target.mesh = BoxMesh.new()
	# Moved from _process on the wall clock, so it must not be interpolated
	# between physics ticks.
	_target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_target)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 5)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(light)


func latency_target() -> Node3D:
	return _target


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo or event.physical_keycode != key:
		return
	if event.pressed and _t0 == 0:
		_t0 = Time.get_ticks_usec()
	elif not event.pressed:
		_t0 = 0
		_moved = false
		_target.position = Vector3.ZERO


func _process(_delta: float) -> void:
	if _t0 > 0 and not _moved and Time.get_ticks_usec() - _t0 >= delay_usec:
		_moved = true
		_target.position = Vector3(0.1, 0, 0)
