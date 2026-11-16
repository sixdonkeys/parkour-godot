class_name WorldClock
extends Node
## The world tick of a loaded level: how many physics ticks the level has
## simulated. Moving surfaces and hazards are pure functions of it (decision
## multiplayer-readiness), so two machines agree given the tick alone. One
## per level, as a child of the level root. It counts before anything else
## in the tick reads it.

const GROUP := "world_clock"

var tick := 0


func _init() -> void:
	process_physics_priority = -1000
	add_to_group(GROUP)


func _physics_process(_delta: float) -> void:
	tick += 1


func reset() -> void:
	tick = 0


## The world tick as seen from `node`, or 0 when its level has no clock.
static func tick_for(node: Node) -> int:
	if node == null or not node.is_inside_tree():
		return 0
	var c := node.get_tree().get_first_node_in_group(GROUP)
	return (c as WorldClock).tick if c else 0
