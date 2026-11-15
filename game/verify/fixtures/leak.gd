extends Node3D
## Known-answer fixture for the leak flag: every load keeps 16 MiB of heap and a
## 1024x1024 RGBA8 texture (4 MiB of video memory) alive in a static list that
## is never cleared, so memory after each unload is higher than the one before.

static var _kept: Array = []


func _ready() -> void:
	var bytes := PackedByteArray()
	bytes.resize(16 * 1024 * 1024)
	bytes.fill(_kept.size() + 1)  # touch the pages so they count as resident
	var img := Image.create_empty(1024, 1024, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.6))
	_kept.append([bytes, ImageTexture.create_from_image(img)])
