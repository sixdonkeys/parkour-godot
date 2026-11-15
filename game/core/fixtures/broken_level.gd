extends Node3D
## Fixture for failure isolation: raises an engine error while starting.

func _ready() -> void:
	var missing: Node = get_node_or_null("DoesNotExist")
	missing.queue_free()  # deliberate: calling a method on null is a script error
