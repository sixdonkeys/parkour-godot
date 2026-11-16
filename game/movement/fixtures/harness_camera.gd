extends Camera3D
## A camera for movement's fixtures only, so frame strips can show a body
## running the course before the `camera` module exists. It is not the game's
## camera and nothing in the simulation reads it: it follows the body's
## interpolated transform in _process, which is the pattern the real rig
## will use.

var body: PlayerBody
var mode := "chase"
var distance := 5.5
var height := 2.4
var offset := Vector3(6, 3, 0)


func _ready() -> void:
	# The camera places itself every frame from interpolated transforms.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if mode == "first" and body:
		# From inside the placeholder its own visor fills the view.
		body.set_placeholder_visible(false)


func _process(_delta: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var xf := body.get_global_transform_interpolated()
	var feet := xf.origin
	var back := xf.basis.z.slide(Vector3.UP).normalized()
	match mode:
		"first":
			global_position = feet + Vector3(0, body.tuning.eye_height, 0)
			var fwd := (-back).rotated(back.cross(Vector3.UP).normalized(), -body.pitch)
			look_at(global_position + fwd, Vector3.UP)
		"side":
			global_position = feet + offset
			look_at(feet + Vector3(0, 1.0, 0), Vector3.UP)
		"top":
			global_position = feet + Vector3(0, distance * 3.0, 0.01)
			look_at(feet, Vector3.FORWARD)
		_:
			global_position = feet + back * distance + Vector3(0, height, 0)
			look_at(feet + Vector3(0, 1.2, 0), Vector3.UP)
