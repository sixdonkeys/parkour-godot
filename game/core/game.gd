extends Node
## Game (autoload): run state, the game loop's top level, level loading with
## failure isolation, the event bus, the window rules and the quality profile.
## See ARCHITECTURE.md (core) and decisions windowing, quality-profiles,
## multiplayer-readiness.

signal level_loaded(id: String)
signal level_failed(id: String, error: String)
signal level_unloaded(id: String)
signal run_started
signal run_paused
signal run_resumed
signal focus_lost
signal quality_changed(profile: QualityProfile)

enum RunState { MENU, LOADING, PLAYING, PAUSED }

const MENU_SCENES: PackedStringArray = ["res://interface/main_menu.tscn", "res://core/menu_placeholder.tscn"]
const PROFILE_DIR := "res://profiles"
const DEFAULT_PROFILE := "neo"
## Errors raised while a level loads, or during its first frames, fail the load.
const LOAD_WATCH_FRAMES := 3

var run_state := RunState.MENU
var quality: QualityProfile
var level_id := ""
var level_root: Node = null
var last_error := ""
var focused := true

var _watch: ErrorWatch
var _menu: Node = null


func _init() -> void:
	_watch = ErrorWatch.new()
	OS.add_logger(_watch)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputDefaults.ensure()
	set_quality(DEFAULT_PROFILE)


# --- quality profile ----------------------------------------------------------

func set_quality(profile_name: String) -> void:
	var path := PROFILE_DIR.path_join(profile_name + ".tres")
	var p: QualityProfile = null
	if ResourceLoader.exists(path):
		p = load(path) as QualityProfile
	if p == null:
		push_error("core: quality profile %s missing or broken; using built-in neo defaults" % path)
		p = QualityProfile.new()
	quality = p
	quality.apply(get_tree().root, level_root)
	quality_changed.emit(quality)


# --- levels --------------------------------------------------------------------

## Load a level by scene path. On any failure the half-made level is freed,
## the error is logged and the player is returned to the menu; the game
## itself keeps running.
func load_level(scene_path: String, id := "") -> Error:
	if id.is_empty():
		id = scene_path.get_base_dir().get_file()
	if level_root:
		unload_level()
	run_state = RunState.LOADING
	level_id = id
	var mark := _watch.count()
	if not ResourceLoader.exists(scene_path):
		return _fail(id, "level scene not found: %s" % scene_path)
	var err := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if err != OK:
		return _fail(id, "could not start loading %s (%s)" % [scene_path, error_string(err)])
	while true:
		var status := ResourceLoader.load_threaded_get_status(scene_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return _fail(id, "loading %s failed (status %d)" % [scene_path, status])
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed == null:
		return _fail(id, "%s is not a scene" % scene_path)
	var inst := packed.instantiate()
	if inst == null:
		return _fail(id, "%s could not be instantiated" % scene_path)
	_close_menu()
	level_root = inst
	get_tree().root.add_child(inst)
	quality.apply(get_tree().root, inst)
	for i in LOAD_WATCH_FRAMES:
		await get_tree().process_frame
	var new_errors := _watch.since(mark)
	if not new_errors.is_empty():
		return _fail(id, "errors while starting %s: %s" % [scene_path, new_errors[0]])
	run_state = RunState.MENU
	level_loaded.emit(id)
	return OK


func unload_level() -> void:
	if level_root == null:
		return
	end_run()
	var id := level_id
	level_root.queue_free()
	level_root = null
	level_id = ""
	Players.clear()
	level_unloaded.emit(id)


func _fail(id: String, message: String) -> Error:
	last_error = message
	push_error("core: level '%s' failed: %s" % [id, message])
	_log_failure(id, message)
	if level_root:
		level_root.queue_free()
		level_root = null
	Players.clear()
	level_id = ""
	run_state = RunState.MENU
	level_failed.emit(id, message)
	open_menu()
	return FAILED


func _log_failure(id: String, message: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f := FileAccess.open("user://logs/level-failures.log", FileAccess.READ_WRITE if FileAccess.file_exists("user://logs/level-failures.log") else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line("%s\t%s\t%s" % [Time.get_datetime_string_from_system(true), id, message])


# --- menu ------------------------------------------------------------------------

func open_menu() -> void:
	release_pointer()
	if _menu and is_instance_valid(_menu):
		return
	for path in MENU_SCENES:
		if ResourceLoader.exists(path):
			var packed = load(path)
			if packed is PackedScene:
				_menu = packed.instantiate()
				get_tree().root.add_child.call_deferred(_menu)
				return
	push_error("core: no menu scene could be loaded")


func _close_menu() -> void:
	if _menu and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


# --- runs, pause and the window rules -----------------------------------------

func start_run() -> void:
	run_state = RunState.PLAYING
	get_tree().paused = false
	capture_pointer()
	run_started.emit()


func end_run() -> void:
	if run_state in [RunState.PLAYING, RunState.PAUSED]:
		run_state = RunState.MENU
	get_tree().paused = false
	release_pointer()


func pause() -> void:
	if run_state != RunState.PLAYING:
		return
	run_state = RunState.PAUSED
	get_tree().paused = true
	release_pointer()
	run_paused.emit()


func resume() -> void:
	if run_state != RunState.PAUSED:
		return
	run_state = RunState.PLAYING
	get_tree().paused = false
	capture_pointer()
	run_resumed.emit()


## The pointer is held only during play in a focused window.
func capture_pointer() -> void:
	if run_state == RunState.PLAYING and focused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_pointer() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func toggle_fullscreen() -> void:
	# Fullscreen, not exclusive: leaving it hands the window back to the
	# window manager, which restores its tile.
	if DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func quit() -> void:
	AppExit.quit(get_tree())


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			focused = false
			release_pointer()
			if run_state == RunState.PLAYING:
				pause()
			focus_lost.emit()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			focused = true
		NOTIFICATION_WM_CLOSE_REQUEST:
			quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if run_state == RunState.PLAYING:
			pause()
		elif run_state == RunState.PAUSED:
			resume()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and run_state == RunState.PLAYING:
		capture_pointer()


func run_state_snapshot() -> Dictionary:
	return {"run_state": RunState.keys()[run_state], "paused": get_tree().paused, "focused": focused,
		"pointer_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "level": level_id,
		"players": Players.slots.size(), "quality": quality.profile_name if quality else "",
		"menu_open": _menu != null and is_instance_valid(_menu),
		"super_bindings": InputDefaults.super_bindings()}
