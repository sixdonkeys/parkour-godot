extends Node
## A quick, headless way to run a movement preset's simulation while working
## on the body: no window, no drawing, as fast as the processor goes. Its
## numbers are not evidence (the verification tool's are); it exists so a
## ten-minute fuzz can be tried in seconds.
##
##   godot --headless --fixed-fps 60 --path game res://movement/fixtures/headless_runner.tscn \
##       -- --dev-preset <preset.json> [--dev-out <result.json>] [--repo-root <dir>] [--dev-ticks N]

var _scene: Node
var _ticks := 0
var _limit := 0
var _out := ""
var _root := ""
var _trace := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var preset_path := _arg(args, "--dev-preset")
	_out = _arg(args, "--dev-out")
	_root = _arg(args, "--repo-root")
	_trace = int(_arg(args, "--dev-trace", "0"))
	if preset_path.is_empty():
		push_error("headless runner: --dev-preset <file> is required")
		get_tree().quit(2)
		return
	var preset = JSON.parse_string(FileAccess.get_file_as_string(preset_path))
	if not (preset is Dictionary):
		push_error("headless runner: cannot read %s" % preset_path)
		get_tree().quit(2)
		return
	var fixture: Dictionary = preset.get("fixture", {})
	var course := String(fixture.get("course", ""))
	if not course.is_empty() and not course.begins_with("res://") and not course.is_absolute_path():
		fixture["course"] = _root.path_join(course)
	_limit = int(_arg(args, "--dev-ticks", str(int(preset.get("frames", 600)) * 2)))
	var packed = load(String(preset.get("scene", "")))
	if not (packed is PackedScene):
		push_error("headless runner: cannot load scene %s" % preset.get("scene", ""))
		get_tree().quit(2)
		return
	_scene = packed.instantiate()
	add_child(_scene)
	if _scene.has_method("configure_fixture"):
		_scene.configure_fixture(fixture)
	if preset.has("input_script"):
		var script = preset["input_script"]
		if script is String:
			var path := String(script)
			if not path.begins_with("res://") and not path.is_absolute_path():
				path = _root.path_join(path)
			script = JSON.parse_string(FileAccess.get_file_as_string(path))
		var harness: Node = load("res://verify/input_harness.gd").new()
		if harness.setup(script):
			add_child(harness)
	process_physics_priority = 3000


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _trace > 0 and _ticks % _trace == 0 and "bodies" in _scene:
		for b in _scene.bodies:
			print("TRACE %d %s pos=(%.3f %.3f %.3f) vel=(%.2f %.2f %.2f) %s floor=%s wall=%s" % [_ticks, b.name,
				b.global_position.x, b.global_position.y, b.global_position.z, b.velocity.x, b.velocity.y, b.velocity.z,
				PlayerBody.State.keys()[b.state], b.is_on_floor(), b.is_on_wall()])
	var done: bool = _scene.has_method("verify_finished") and _scene.verify_finished()
	if done or _ticks >= _limit:
		var rep: Dictionary = _scene.verify_report() if _scene.has_method("verify_report") else {}
		rep["headless_ticks"] = _ticks
		var text := JSON.stringify(rep, "  ", false)
		if _out.is_empty():
			print(text)
		else:
			var f := FileAccess.open(_out, FileAccess.WRITE)
			f.store_string(text)
			f.close()
			print("headless runner: wrote ", _out)
		set_physics_process(false)
		get_tree().quit(0)


static func _arg(args: PackedStringArray, key: String, fallback := "") -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback
