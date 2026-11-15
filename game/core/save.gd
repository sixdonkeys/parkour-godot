extends Node
## Saved data (autoload `Save`): one JSON file in user://, written atomically.
## A corrupt file is moved aside and replaced by defaults; it never stops the
## game starting (ARCHITECTURE.md, Failure isolation).

const PATH := "user://save.json"
const VERSION := 1

var _data: Dictionary = {"version": VERSION}
var _dirty := false
var last_error := ""


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var text := FileAccess.get_file_as_string(PATH)
	# JSON.parse() returns an error code; JSON.parse_string() would also raise
	# an engine error, which a corrupt save file must not do.
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		_data = json.data
		return
	var aside := PATH + ".corrupt-%d" % int(Time.get_unix_time_from_system())
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(aside))
	last_error = "save file was corrupt; moved to %s and started from defaults" % aside
	push_warning(last_error)
	_data = {"version": VERSION}


func read(key: String, default: Variant = null) -> Variant:
	return _data.get(key, default)


func write(key: String, value: Variant) -> void:
	_data[key] = value
	_dirty = true


func flush() -> Error:
	if not _dirty:
		return OK
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save: cannot write %s (%s)" % [tmp, FileAccess.get_open_error()])
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(_data, "  "))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))
	if err == OK:
		_dirty = false
	else:
		push_error("save: cannot replace %s (%s)" % [PATH, err])
	return err


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		flush()
