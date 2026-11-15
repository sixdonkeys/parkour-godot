extends Node
## Players (autoload `Players`): the list of player slots in the loaded world.
## Nothing in the game assumes exactly one player (decision
## multiplayer-readiness). The local human is just a slot with a device input.

signal slot_added(slot: PlayerSlot)
signal slot_removed(slot: PlayerSlot)

var slots: Array[PlayerSlot] = []
var _next_id := 1


func add(input: InputSource, look: Dictionary = {}, is_ghost := false) -> PlayerSlot:
	var s := PlayerSlot.new()
	s.player_id = _next_id
	_next_id += 1
	s.input = input
	s.look = look
	s.is_ghost = is_ghost
	slots.append(s)
	slot_added.emit(s)
	return s


func remove(slot: PlayerSlot) -> void:
	slots.erase(slot)
	slot_removed.emit(slot)


func clear() -> void:
	for s in slots.duplicate():
		remove(s)
	_next_id = 1


func get_slot(player_id: int) -> PlayerSlot:
	for s in slots:
		if s.player_id == player_id:
			return s
	return null


func slot_for_body(body: Node) -> PlayerSlot:
	for s in slots:
		if s.body == body:
			return s
	return null


## The slots driven by a person at this machine (for pointer capture, HUD).
func local_humans() -> Array[PlayerSlot]:
	var out: Array[PlayerSlot] = []
	for s in slots:
		if s.input is DeviceInput:
			out.append(s)
	return out
