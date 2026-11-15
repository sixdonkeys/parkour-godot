extends Logger
## Collects every engine error and warning so the verification log can report
## them; the engine itself exits 0 after errors (decision verification-rendering).

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []
var _mutex := Mutex.new()

const _TYPES := ["error", "warning", "script", "shader"]


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var entry := {
		"type": _TYPES[error_type] if error_type < _TYPES.size() else str(error_type),
		"message": rationale if not rationale.is_empty() else code,
		"code": code,
		"where": "%s:%d (%s)" % [file, line, function],
		"usec": Time.get_ticks_usec(),
	}
	_mutex.lock()
	if error_type == ERROR_TYPE_WARNING:
		warnings.append(entry)
	else:
		errors.append(entry)
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func snapshot() -> Dictionary:
	_mutex.lock()
	var d := {"errors": errors.duplicate(true), "warnings": warnings.duplicate(true)}
	_mutex.unlock()
	return d


func mark() -> Vector2i:
	_mutex.lock()
	var m := Vector2i(errors.size(), warnings.size())
	_mutex.unlock()
	return m


func since(m: Vector2i) -> Dictionary:
	_mutex.lock()
	var d := {"errors": errors.slice(m.x), "warnings": warnings.slice(m.y)}
	_mutex.unlock()
	return d
