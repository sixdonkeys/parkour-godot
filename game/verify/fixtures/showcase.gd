extends Node3D
## verify's showcase scene: enough content that a still shows something (lit
## shapes with checker textures, shadows, sky), so the test-mode/normal-launch
## pair and SSIM between rounds can tell a change from none. Built in code from
## a fixed layout; no third-party assets.

func _ready() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = _checker(Color(0.55, 0.5, 0.42), Color(0.42, 0.38, 0.32), 20.0)
	add_child(ground)
	var shapes: Array[Mesh] = [BoxMesh.new(), SphereMesh.new(), CylinderMesh.new(), TorusMesh.new(), PrismMesh.new()]
	var colours := [Color(0.8, 0.3, 0.2), Color(0.2, 0.5, 0.8), Color(0.3, 0.7, 0.35), Color(0.85, 0.75, 0.3), Color(0.6, 0.4, 0.7)]
	for i in shapes.size():
		var mi := MeshInstance3D.new()
		mi.mesh = shapes[i]
		mi.position = Vector3((i - 2) * 2.2, 0.75, -1.5 - (i % 2) * 1.5)
		mi.rotation_degrees = Vector3(0, i * 23.0, 0)
		mi.material_override = _checker(colours[i], colours[i].darkened(0.35), 4.0)
		add_child(mi)


func _checker(a: Color, b: Color, repeats: float) -> StandardMaterial3D:
	var img := Image.create_empty(64, 64, true, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, a if ((x / 8) + (y / 8)) % 2 == 0 else b)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_scale = Vector3(repeats, repeats, repeats)
	m.roughness = 0.7
	return m
