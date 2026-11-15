extends Node3D
## Critic's own known-answer fixture for the memory instrument (verify round 1):
## one uncompressed RGBA8 texture of 2048 x 2048 without mipmaps = 16,777,216 bytes.

const SIZE := 2048

var _tex: ImageTexture


func _ready() -> void:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.6, 0.3, 1.0))
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
