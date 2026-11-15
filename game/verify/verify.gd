extends Node
## In-game half of the verification tool (module `verify`).
##
## Does nothing on a normal launch. With user arguments after `--` it runs
## presets and writes PNGs, WAVs and a JSON log:
##   --preset <file.json>[,<file2.json>...]   run these presets
##   --bench [<dir>]                           run every bundled benchmark preset
##   --out <dir>                               where results go
##   --test-mode                               fixed timing (launch with --fixed-fps 60)
##   --commit <hash>                           the build's commit, for the log
## See docs/decisions/verification-rendering.md.

const ErrorLogger := preload("res://verify/error_logger.gd")
const FrameStats := preload("res://verify/frame_stats.gd")
const MemProbe := preload("res://verify/mem_probe.gd")
const AudioTap := preload("res://verify/audio_tap.gd")
const BENCH_DIR := "res://verify/bench_presets"
const BUILD_INFO := "res://verify/build_info.json"
const SOFTWARE_RE := "llvmpipe|lavapipe|softpipe|swiftshader|microsoft basic"

var logger: ErrorLogger
var active := false
var test_mode := false
var commit := ""
var _audio: AudioTap = null
var _args: Dictionary = {}
var _scene_holder: Node = null
var _frame := 0


func _init() -> void:
	logger = ErrorLogger.new()
	OS.add_logger(logger)


func _ready() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	test_mode = _args.has("test-mode")
	commit = _args.get("commit", _build_info().get("commit", "unknown"))
	if _args.has("preset") or _args.has("bench"):
		active = true
		# Benchmarks measure what a frame costs, not the display's refresh:
		# vsync off where the driver allows it, else mailbox (uncapped, no tearing).
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MAILBOX)
		# --bench-fullscreen: the harness (not the game) makes the window
		# fullscreen so the compositor scans it out directly and its own frame
		# pacing doesn't land in the game's numbers. Window presets skip it.
		if _args.has("bench-fullscreen"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run_all.call_deferred()


var focus_events: Array[Dictionary] = []
## A fixture scene may put its own verdict here; it goes into the log.
var fixture_result: Dictionary = {}


func _notification(what: int) -> void:
	if not active:
		return
	var names := {NOTIFICATION_APPLICATION_FOCUS_OUT: "app_focus_out", NOTIFICATION_APPLICATION_FOCUS_IN: "app_focus_in",
		NOTIFICATION_WM_WINDOW_FOCUS_OUT: "window_focus_out", NOTIFICATION_WM_WINDOW_FOCUS_IN: "window_focus_in"}
	if names.has(what):
		focus_events.append({"event": names[what], "frame": _frame, "usec": Time.get_ticks_usec()})


## The sound system reports each sound it plays, for the sound log.
func note_sound(sound_name: String, peak_db: float) -> void:
	if _audio:
		_audio.note(sound_name, peak_db)


func _parse_args(a: PackedStringArray) -> Dictionary:
	var d := {}
	var i := 0
	while i < a.size():
		var k := a[i]
		if k.begins_with("--"):
			var key := k.substr(2)
			if i + 1 < a.size() and not a[i + 1].begins_with("--"):
				d[key] = a[i + 1]
				i += 1
			else:
				d[key] = ""
		i += 1
	return d


func _build_info() -> Dictionary:
	if FileAccess.file_exists(BUILD_INFO):
		var j = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO))
		if j is Dictionary:
			return j
	return {}


func _run_all() -> void:
	var presets: Array[String] = []
	var out_root: String = _args.get("out", "")
	if _args.has("bench"):
		var index := _load_json(BENCH_DIR.path_join("index.json"))
		for f in index.get("presets", []):
			presets.append(BENCH_DIR.path_join(String(f)))
		if presets.is_empty():
			push_error("verify: no benchmark presets bundled (missing %s/index.json)" % BENCH_DIR)
		if out_root.is_empty():
			out_root = _args.get("bench", "")
		if out_root.is_empty():
			out_root = OS.get_user_data_dir().path_join("bench").path_join(
				Time.get_datetime_string_from_system().replace(":", "-") + "-" + commit.left(8))
	else:
		for p in String(_args["preset"]).split(","):
			presets.append(p)
	if out_root.is_empty():
		out_root = OS.get_user_data_dir().path_join("verify")
	DirAccess.make_dir_recursive_absolute(out_root)
	print("VERIFY out=", out_root)
	var summary := []
	for p in presets:
		var preset := _load_json(p)
		if preset.is_empty():
			push_error("verify: cannot read preset %s" % p)
			summary.append({"preset": p, "error": "unreadable"})
			continue
		var out_dir := out_root if presets.size() == 1 and not _args.has("bench") else out_root.path_join(preset.get("id", p.get_file().get_basename()))
		DirAccess.make_dir_recursive_absolute(out_dir)
		var log := await _run_preset(preset, out_dir)
		summary.append({"preset": preset.get("id", p), "errors": log["engine"]["errors"].size(),
			"frame_pass": log.get("frame_time", {}).get("budget", {}).get("pass", null)})
	if _args.has("bench"):
		_write_json(out_root.path_join("bench-summary.json"), {"commit": commit, "presets": summary,
			"machine": _machine_info()})
	print("VERIFY done")
	quit_safely(0)


## Quit through core's single exit path (works around Godot issue #123059).
func quit_safely(code: int) -> void:
	AppExit.quit(get_tree(), code)


## Repo-relative paths in presets resolve against --repo-root (given by the
## orchestrator); res:// and absolute paths are used as they are.
func _resolve(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return path
	return String(_args.get("repo-root", "")).path_join(path)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(path))
	return j if j is Dictionary else {}


func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  ", false))
		f.close()
	else:
		push_error("verify: cannot write %s" % path)


func _machine_info() -> Dictionary:
	var name := RenderingServer.get_video_adapter_name()
	return {
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"cpu_cores": OS.get_processor_count(),
		"engine": Engine.get_version_info().get("string", ""),
		"adapter": name,
		"adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"adapter_api_version": RenderingServer.get_video_adapter_api_version(),
		"adapter_driver": OS.get_video_adapter_driver_info(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_device_name": RenderingServer.get_rendering_device().get_device_name() if RenderingServer.get_rendering_device() else "",
		"rendering_device_vendor": RenderingServer.get_rendering_device().get_device_vendor_name() if RenderingServer.get_rendering_device() else "",
		"display_server": DisplayServer.get_name(),
		"software_renderer": name.is_empty() or RegEx.create_from_string(SOFTWARE_RE).search(name.to_lower()) != null,
		"screen_size": DisplayServer.screen_get_size(),
		"screen_scale": DisplayServer.screen_get_scale(),
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"desktop": OS.get_environment("XDG_CURRENT_DESKTOP"),
	}


# --- one preset -------------------------------------------------------------

func _run_preset(p: Dictionary, out_dir: String) -> Dictionary:
	var mark := logger.mark()
	var root := get_tree().root
	var log := {
		"preset": p, "commit": commit, "test_mode": test_mode,
		"timing": "fixed (--fixed-fps)" if test_mode else "real time",
		"started": Time.get_datetime_string_from_system(true),
		"machine": _machine_info(),
	}
	log["proxy"] = true  # harness addendum: every number is a Neo proxy until the Neo returns
	# Resolution: pin the root viewport to the preset's size (window untouched),
	# or follow the window when the preset says "window".
	var res = p.get("resolution", "window")
	if res is Array:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.content_scale_size = Vector2i(int(res[0]), int(res[1]))
	Engine.max_fps = int(p.get("max_fps", 0))
	# A base scene stands in for what stays loaded around a level (the menu's
	# 3D backdrop), so render buffers that live for the whole session are in
	# the baseline, not counted as the level's memory.
	var base: Node = null
	if p.has("base_scene"):
		var bp = ResourceLoader.load(String(p["base_scene"]))
		if bp is PackedScene:
			base = bp.instantiate()
			base.name = "VerifyBase"
			root.add_child(base)
		else:
			push_error("verify: cannot load base scene %s" % p["base_scene"])
	# Let the viewport reach its preset size and settle before the baseline reading.
	for i in 10:
		await RenderingServer.frame_post_draw
	var mem := [MemProbe.reading("before_load")]
	var scene_path: String = p.get("scene", "")
	# Optional load/unload cycles before the measured run, to tell a bounded
	# engine pool (stays flat across cycles) from a leak (grows every cycle).
	var cycles := []
	for c in int(p.get("precycles", 0)):
		var pk = ResourceLoader.load(scene_path)
		if pk is PackedScene:
			var holder := Node.new()
			root.add_child(holder)
			holder.add_child(pk.instantiate())
			for i in 10:
				await RenderingServer.frame_post_draw
			var loaded := MemProbe.reading("precycle_%d_loaded" % c)
			holder.queue_free()
			for i in int(p.get("unload_frames", 30)):
				await RenderingServer.frame_post_draw
			cycles.append([loaded, MemProbe.reading("precycle_%d_unloaded" % c)])
	# Load the scene.
	var scene: Node = null
	if not scene_path.is_empty():
		var packed = ResourceLoader.load(scene_path)
		if packed is PackedScene:
			scene = packed.instantiate()
			_scene_holder = Node.new()
			_scene_holder.name = "VerifyScene"
			root.add_child(_scene_holder)
			_scene_holder.add_child(scene)
		else:
			push_error("verify: cannot load scene %s" % scene_path)
	log["scene_loaded"] = scene != null
	if scene and scene.has_method("configure_fixture"):
		scene.configure_fixture(p.get("fixture", {}))
	if scene and p.has("time_of_day") and scene.has_method("set_time_of_day"):
		scene.set_time_of_day(float(p["time_of_day"]))
	log["profile"] = _apply_profile(String(p.get("profile", "neo")), scene)
	# Camera.
	var cam: Camera3D = null
	var path := {}
	if p.has("camera") or p.has("camera_path"):
		cam = Camera3D.new()
		cam.name = "VerifyCamera"
		(_scene_holder if _scene_holder else root).add_child(cam)
		cam.current = true
		if p.has("camera_path"):
			path = _load_json(_resolve(String(p["camera_path"])))
			if path.is_empty():
				push_error("verify: cannot read camera path %s" % p["camera_path"])
		else:
			_pose_camera(cam, p["camera"])
	# Sound.
	if p.get("sound", false):
		_audio = AudioTap.new()
		_audio.start()
	var stats := FrameStats.new()
	stats.start(root)
	var warmup := int(p.get("warmup_frames", 30))
	var frames := int(p.get("frames", 120))
	if not path.is_empty() and test_mode:
		frames = int(ceil(float(path.get("duration_s", 1.0)) * 60.0))
	var still_frame := int(p.get("still_frame", frames - 1))
	var strip_every := int(p.get("strip_every", 0))
	var seq: Array = p.get("window_sequence", [])
	var window_log := []
	var t0 := Time.get_ticks_usec()
	_frame = -warmup
	var path_t0_usec := -1
	while _frame < frames:
		if cam and not path.is_empty():
			if _frame == 0 or path_t0_usec < 0:
				path_t0_usec = Time.get_ticks_usec()
			var t := (maxi(_frame, 0) / 60.0) if test_mode else (Time.get_ticks_usec() - path_t0_usec) / 1e6
			_pose_on_path(cam, path, t)
		for step in seq:
			if int(step.get("frame", -1)) == _frame:
				await _window_action(step, window_log)
		await RenderingServer.frame_post_draw
		if _frame >= 0:
			stats.sample()
			if _audio:
				_audio.drain()
			if _frame == still_frame and p.get("still", true):
				_save_frame(out_dir.path_join("still.png"))
				stats.mark_capture()
			if strip_every > 0 and _frame % strip_every == 0:
				DirAccess.make_dir_recursive_absolute(out_dir.path_join("strip"))
				_save_frame(out_dir.path_join("strip/%05d.png" % _frame))
				stats.mark_capture()
		elif _frame == -1:
			stats.start(root)  # discard warm-up
		for w in window_log:
			if w.get("observe_at", -999) == _frame:
				w["observed"] = _window_state()
		_frame += 1
	log["wall_seconds"] = (Time.get_ticks_usec() - t0) / 1e6
	log["frame_time"] = stats.report(true)
	if Engine.max_fps > 0:
		log["frame_time"]["frame_limiter_fps"] = Engine.max_fps
	log["viewport_size"] = root.get_visible_rect().size
	log["window_size"] = DisplayServer.window_get_size()
	if not seq.is_empty():
		log["window_sequence"] = window_log
		log["window_wm"] = p.get("window_wm", OS.get_environment("XDG_CURRENT_DESKTOP"))
	log["interface_outside"] = _controls_outside()
	if not fixture_result.is_empty():
		log["fixture_result"] = fixture_result.duplicate(true)
		fixture_result.clear()
	log["focus_events"] = focus_events.duplicate()
	focus_events.clear()
	mem.append(MemProbe.reading("after_load"))
	if _audio:
		_audio.stop()
		log["sound"] = _audio.analyse()
		_audio.write_wav(out_dir.path_join("audio.wav"))
		_audio = null
	# Unload and read memory again.
	if _scene_holder:
		_scene_holder.queue_free()
		_scene_holder = null
	for i in int(p.get("unload_frames", 30)):
		await RenderingServer.frame_post_draw
	mem.append(MemProbe.reading("after_unload"))
	if base:
		base.queue_free()
	log["memory"] = _memory_report(mem)
	if not cycles.is_empty():
		var m: Dictionary = log["memory"]
		m["precycles"] = cycles
		# Warm-cycle return: compare the measured unload with the previous
		# cycle's unload, so a bounded engine pool that grows once (the
		# upload staging buffer) is told apart from a leak that grows each time.
		var warm: int = cycles[-1][1]["total_bytes"]
		var after_t: int = mem[2]["total_bytes"]
		# Nick's decision (2026-11-15, ARCHITECTURE.md): the 5% is judged against
		# the warm cycle; the literal first-load return is reported and decides nothing.
		m["literal_returns_within_5pct"] = m["returns_within_5pct"]
		m["warm_baseline_bytes"] = warm
		m["warm_return_ratio"] = (float(after_t) / warm) if warm > 0 else null
		m["returns_within_5pct"] = warm > 0 and absf(float(after_t) / warm - 1.0) <= 0.05
		# A leak keeps growing; a cache or heap settles. Compare the last two
		# unloads (the last pre-cycle and the measured one): more than 1% up
		# means still growing. The full series stays in the log.
		var last_unloads: Array = []
		for c in cycles:
			last_unloads.append(c[1]["total_bytes"])
		last_unloads.append(after_t)
		m["unload_series_bytes"] = last_unloads
		# Like for like: each cycle's unload against the cycle before it; growth
		# in every step means a leak (critic round 1: comparing only the measured
		# cycle with a warm-up cycle gave a false alarm).
		var grows := last_unloads.size() >= 3
		for i in range(1, last_unloads.size()):
			if last_unloads[i] <= last_unloads[i - 1] * 1.01:
				grows = false
		m["grows_each_cycle"] = grows
	Engine.max_fps = 0
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1280, 800)
	log["engine"] = logger.since(mark)
	log["finished"] = Time.get_datetime_string_from_system(true)
	_write_json(out_dir.path_join("log.json"), log)
	return log


func _apply_profile(profile_name: String, scene: Node) -> Dictionary:
	var path := "res://profiles/%s.tres" % profile_name
	var info := {"name": profile_name, "path": path, "loaded": false,
		"render_scale": get_tree().root.scaling_3d_scale}
	if ResourceLoader.exists(path):
		var prof = load(path)
		if prof and prof.has_method("apply"):
			prof.apply(get_tree().root, scene)
			info["loaded"] = true
			info["render_scale"] = get_tree().root.scaling_3d_scale
			if prof.has_method("describe"):
				info["settings"] = prof.describe()
	return info


func _memory_report(r: Array) -> Dictionary:
	var before: int = r[0]["total_bytes"]
	var loaded: int = r[1]["total_bytes"]
	var after: int = r[2]["total_bytes"]
	return {
		"readings": r,
		"loaded_total_bytes": loaded,
		"within_4gb": loaded >= 0 and loaded <= 4 * 1024 * 1024 * 1024,
		"unload_return_ratio": (float(after) / before) if before > 0 else null,
		"returns_within_5pct": before > 0 and absf(float(after) / before - 1.0) <= 0.05,
		"video_delta_load_bytes": r[1]["video_bytes"] - r[0]["video_bytes"],
		"texture_delta_load_bytes": r[1]["texture_bytes"] - r[0]["texture_bytes"],
	}


func _pose_camera(cam: Camera3D, c: Dictionary) -> void:
	var pos := _v3(c.get("position", [0, 1.7, 5]))
	cam.fov = float(c.get("fov", 70.0))
	cam.far = float(c.get("far", 4000.0))
	cam.near = float(c.get("near", 0.05))
	cam.position = pos
	if c.has("look_at"):
		cam.look_at_from_position(pos, _v3(c["look_at"]), Vector3.UP)


func _pose_on_path(cam: Camera3D, path: Dictionary, t: float) -> void:
	var keys: Array = path.get("keys", [])
	if keys.is_empty():
		return
	var i := 0
	while i < keys.size() - 1 and float(keys[i + 1]["t"]) <= t:
		i += 1
	var k1: Dictionary = keys[i]
	var k2: Dictionary = keys[mini(i + 1, keys.size() - 1)]
	var k0: Dictionary = keys[maxi(i - 1, 0)]
	var k3: Dictionary = keys[mini(i + 2, keys.size() - 1)]
	var span := maxf(float(k2["t"]) - float(k1["t"]), 1e-6)
	var w := clampf((t - float(k1["t"])) / span, 0.0, 1.0)
	var pos := _v3(k1["pos"]).cubic_interpolate(_v3(k2["pos"]), _v3(k0["pos"]), _v3(k3["pos"]), w)
	var look := _v3(k1["look_at"]).cubic_interpolate(_v3(k2["look_at"]), _v3(k0["look_at"]), _v3(k3["look_at"]), w)
	cam.fov = lerpf(float(k1.get("fov", 70)), float(k2.get("fov", 70)), w)
	cam.far = float(path.get("far", 4000.0))
	cam.look_at_from_position(pos, look, Vector3.UP)


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _save_frame(path: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.save_png(path) != OK:
		push_error("verify: could not save frame %s" % path)


# --- window sequence (harness acting as window manager; decision windowing) ---

func _window_action(step: Dictionary, wlog: Array) -> void:
	var action: String = step["action"]
	var entry := {"frame": _frame, "action": action, "observe_at": _frame + int(step.get("settle_frames", 20))}
	match action:
		"resize_frac":
			var scr := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			var f: Array = step["frac"]
			var sz := Vector2i(int(scr.size.x * float(f[0])), int(scr.size.y * float(f[1])))
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(sz)
			entry["requested"] = sz
		"fullscreen_toggle":
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"focus_out":
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			get_tree().root.propagate_notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			entry["synthetic"] = true
		"focus_in":
			get_tree().root.propagate_notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			entry["synthetic"] = true
		"game_call":
			# Call a method on the Game autoload (e.g. load_level) and record the
			# result and the run state afterwards.
			var g := get_tree().root.get_node_or_null("/root/Game")
			if g and g.has_method(step["method"]):
				var r = await g.callv(step["method"], step.get("args", []))
				entry["result"] = r
			else:
				push_error("verify: Game.%s not available" % step.get("method", "?"))
		"mark":
			# An external window manager acts here (tools/wm/drive_*.py); we observe.
			entry["name"] = step.get("name", "")
			print("VERIFY mark ", step.get("name", ""))
	wlog.append(entry)


func _window_state() -> Dictionary:
	var root := get_tree().root
	var win := DisplayServer.window_get_size()
	var vis := root.get_visible_rect().size
	var s := {
		"root_size": root.size,
		"content_scale_factor": root.content_scale_factor,
		"content_scale_size": root.content_scale_size,
		"screen_scale": DisplayServer.screen_get_scale(),
		"scaling_3d_scale": root.scaling_3d_scale,
		"window_size": win,
		"window_mode": DisplayServer.window_get_mode(),
		"viewport_size": vis,
		"mouse_mode": Input.mouse_mode,
		"pointer_released": Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,
		"paused": get_tree().paused,
		"interface_outside": _controls_outside(),
	}
	# Picture fills the window without stretching: a real frame grab has the
	# window's own pixel size, and the visible canvas has the window's aspect.
	# (ViewportTexture.get_size() is not used: under canvas_items stretch it
	# reports window^2 / base size, not the drawn pixels.)
	var grab := root.get_texture().get_image()
	var px := grab.get_size() if grab else Vector2i.ZERO
	s["frame_pixels"] = px
	s["render_3d_pixels"] = Vector2(root.size) * root.scaling_3d_scale
	if win.x > 0 and win.y > 0 and vis.y > 0:
		s["aspect_window"] = float(win.x) / win.y
		s["aspect_visible"] = vis.x / vis.y
		s["fills_without_stretch"] = px == win and absf(float(win.x) / win.y - vis.x / vis.y) <= 2.0 / win.y
	if root.has_node("/root/Game") and root.get_node("/root/Game").has_method("run_state_snapshot"):
		s["run_state"] = root.get_node("/root/Game").run_state_snapshot()
	return s


## Every visible Control whose rectangle isn't wholly inside the visible area.
func _controls_outside() -> Array:
	var out := []
	var vis := Rect2(Vector2.ZERO, get_tree().root.get_visible_rect().size)
	_collect_outside(get_tree().root, vis, out)
	return out


func _collect_outside(n: Node, vis: Rect2, out: Array) -> void:
	if n is Control and n.is_visible_in_tree() and not n.get_meta("verify_ignore", false):
		var r: Rect2 = (n as Control).get_global_rect()
		var xf: Transform2D = (n as Control).get_viewport().get_canvas_transform() if (n as Control).get_canvas_layer_node() == null else Transform2D.IDENTITY
		r = xf * r
		if r.size.x > 0 and r.size.y > 0 and not vis.grow(0.5).encloses(r):
			out.append({"path": str(n.get_path()), "rect": [r.position.x, r.position.y, r.size.x, r.size.y]})
	for c in n.get_children():
		_collect_outside(c, vis, out)
