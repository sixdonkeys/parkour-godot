extends Node
## First scene. Opens the menu, unless the verification tool is running
## presets (it drives the game itself then).

func _ready() -> void:
	if has_node("/root/Verify") and get_node("/root/Verify").active:
		return
	Game.open_menu()
