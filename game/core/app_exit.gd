class_name AppExit
extends RefCounted
## The one place the game quits. Works around Godot issue #123059: on Wayland
## the engine can wait for ever at shutdown, so after everything is flushed the
## process ends itself instead of running the racy teardown (decision windowing).
## Remove when the engine moves to a release with the fix.


static func quit(tree: SceneTree, code := 0) -> void:
	if Engine.has_singleton("Save") or tree.root.has_node("/root/Save"):
		tree.root.get_node("/root/Save").flush()
	if DisplayServer.get_name() == "Wayland":
		print("VERIFY exit: self-terminated after flush (godot#123059)")
		await tree.process_frame
		OS.kill(OS.get_process_id())
	tree.quit(code)
