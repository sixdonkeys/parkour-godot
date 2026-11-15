extends Node3D
## Known-answer fixture for the memory instrument: one uncompressed RGBA8
## texture of 4096 x 4096 without mipmaps = 67,108,864 bytes of video memory.

const SIZE := 4096
const EXPECTED_BYTES := SIZE * SIZE * 4

var _tex: ImageTexture


func _ready() -> void:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.25, 0.75, 1.0))
	_tex = ImageTexture.create_from_image(img)
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	mi.mesh = quad
	mi.position = Vector3(0, 1.7, 3.5)
	add_child(mi)
	# No camera of its own: the preset's base scene (empty.tscn) supplies it, so
	# the 3D render buffers are already in the baseline reading.
