extends Node3D
## Stand-in main menu until the interface module builds the real one: a 3D
## backdrop (so the session's render buffers exist, as with the real menu)
## and a title.

func _ready() -> void:
	Game.release_pointer()
