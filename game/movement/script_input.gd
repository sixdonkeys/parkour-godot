class_name ScriptInput
extends InputSource
## Action states set at given ticks: a plain, deterministic source for
## fixtures and for a second body. Not the recorded-run format (decision
## replay, still to be written); just "from tick N, hold these".
##
## events: [{"tick": 0, "set": {"move_forward": 1.0}}, {"tick": 240, "set": {"jump": 1.0}, "look": [0.2, 0.0]}]
## `look` is a one-tick turn in radians (x right, y down).

var _events: Array = []
var _next := 0
var _state: Dictionary = {}


func _init(events: Array = []) -> void:
	_events = events.duplicate(true)
	_events.sort_custom(func(a, b): return int(a["tick"]) < int(b["tick"]))


func sample(tick: int) -> Dictionary:
	var d := _state.duplicate()
	d["look_x"] = 0.0
	d["look_y"] = 0.0
	while _next < _events.size() and int(_events[_next]["tick"]) <= tick:
		var e: Dictionary = _events[_next]
		for k in e.get("set", {}):
			_state[k] = float(e["set"][k])
			d[k] = _state[k]
		if e.has("look"):
			d["look_x"] += float(e["look"][0])
			d["look_y"] += float(e["look"][1])
		_next += 1
	return d
