class_name ErrorWatch
extends Logger
## Counts engine errors so core can tell whether a level raised any while it
## loaded (failure isolation). Thread-safe: loggers are called from any thread.

var _errors: PackedStringArray = []
var _mutex := Mutex.new()


func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	_errors.append("%s (%s:%d)" % [rationale if not rationale.is_empty() else code, file, line])
	_mutex.unlock()


func count() -> int:
	_mutex.lock()
	var n := _errors.size()
	_mutex.unlock()
	return n


func since(mark: int) -> PackedStringArray:
	_mutex.lock()
	var s := _errors.slice(mark)
	_mutex.unlock()
	return s
