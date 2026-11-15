extends Node3D
## Stress scene for the benchmark-only build (core): roughly the load a dressed
## level puts on the GPU, built from a fixed seed so every machine draws the
## same thing. A benchmark fixture, not a level: it ships only in benchmark
## builds' preset set and is never part of the game's world generation.

const SEED := 20261115
const GROUND_SIZE := 1000.0
const GROUND_RES := 256
const ROCKS := 40000
const PLANTS := 12000
const TREES := 3000

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_rng.seed = SEED
	_noise.seed = SEED
	_noise.frequency = 0.004
	_noise.fractal_octaves = 5
	_build_environment()
	_build_ground()
	_scatter("Rocks", _rock_mesh(), ROCKS, 0.3, 2.2, 400.0)
	_scatter("Plants", _plant_mesh(), PLANTS, 0.6, 1.8, 200.0)
	_scatter("Trees", _tree_mesh(), TREES, 0.8, 1.6, 600.0)


func height(x: float, z: float) -> float:
	return _noise.get_noise_2d(x, z) * 60.0


func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.0015
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.sdfgi_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	add_child(sun)


func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := GROUND_SIZE / GROUND_RES
	var half := GROUND_SIZE / 2.0
	for zi in GROUND_RES + 1:
		for xi in GROUND_RES + 1:
			var x := xi * step - half
			var z := zi * step - half
			st.set_uv(Vector2(xi, zi) / 8.0)
			st.add_vertex(Vector3(x, height(x, z), z))
	for zi in GROUND_RES:
		for xi in GROUND_RES:
			var i := zi * (GROUND_RES + 1) + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + GROUND_RES + 1)
			st.add_index(i + 1)
			st.add_index(i + GROUND_RES + 2)
			st.add_index(i + GROUND_RES + 1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.5, 0.38)
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)


func _scatter(node_name: String, mesh: Mesh, count: int, min_s: float, max_s: float, range_m: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var x := _rng.randf_range(-GROUND_SIZE / 2, GROUND_SIZE / 2)
		var z := _rng.randf_range(-GROUND_SIZE / 2, GROUND_SIZE / 2)
		var s := _rng.randf_range(min_s, max_s)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.7, 1.3), s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, height(x, z), z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.visibility_range_end = range_m
	add_child(mmi)


func _rock_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radial_segments = 12
	m.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.4, 0.36)
	mat.roughness = 0.9
	m.material = mat
	return m


func _plant_mesh() -> Mesh:
	var m := QuadMesh.new()
	m.size = Vector2(1, 1.2)
	m.center_offset = Vector3(0, 0.6, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.45, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material = mat
	return m


func _tree_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.05
	m.bottom_radius = 1.6
	m.height = 9.0
	m.radial_segments = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.3, 0.15)
	m.material = mat
	return m
