extends Node3D
## look-slice (a probe, never shipped in a game build): a patch of Sonoran
## desert dressed toward the reference photographs, inside the full 1 km of
## generated ground with the backdrop. Sun and sky follow the time of day at
## Tucson's latitude (decision lighting).

const LATITUDE := 32.3
const TERRAIN := "res://look_slice/generated/terrain.tscn"
const PH := "res://assets/polyhaven/"

@export var time_of_day := 13.0
@export var day_of_year := 105  # mid-April

var _sun: DirectionalLight3D
var _env: Environment
var _terrain_mat: ShaderMaterial


func _ready() -> void:
	_build_environment()
	_load_terrain()
	set_time_of_day(time_of_day)
	var scatter := preload("res://look_slice/scatter.gd").new()
	scatter.name = "Scatter"
	add_child(scatter)
	scatter.build(self)


## Verification presets can switch parts off to isolate them.
func configure_fixture(cfg: Dictionary) -> void:
	if not cfg.get("scatter", true) and has_node("Scatter"):
		get_node("Scatter").free()
	if not cfg.get("backdrop", true):
		get_node("Terrain/Backdrop").visible = false


func height_at(x: float, z: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 2000, z), Vector3(x, -500, z))
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else 0.0


func _tex(id: String, map: String) -> Texture2D:
	return load(PH + "%s/%s_%s_4k.jpg" % [id, id, map])


func _load_terrain() -> void:
	var t: Node3D = load(TERRAIN).instantiate()
	add_child(t)
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = load("res://look_slice/terrain.gdshader")
	for layer in [["ground", "gravelly_sand"], ["rocky", "dry_ground_rocks"], ["cliff", "cliff_side"]]:
		_terrain_mat.set_shader_parameter(layer[0] + "_albedo", _tex(layer[1], "diff"))
		_terrain_mat.set_shader_parameter(layer[0] + "_normal", _tex(layer[1], "nor_gl"))
		_terrain_mat.set_shader_parameter(layer[0] + "_rough", _tex(layer[1], "rough"))
	var ao := Image.load_from_file(ProjectSettings.globalize_path("res://look_slice/generated/ao_roam.png"))
	_terrain_mat.set_shader_parameter("sky_ao", ImageTexture.create_from_image(ao))
	for c in t.get_node("Chunks").get_children():
		(c as MeshInstance3D).material_override = _terrain_mat
	var back := t.get_node("Backdrop") as MeshInstance3D
	back.material_override = _terrain_mat


func _build_environment() -> void:
	_env = Environment.new()
	var sky_mat := PhysicalSkyMaterial.new()
	sky_mat.turbidity = 4.0
	sky_mat.mie_coefficient = 0.004
	sky_mat.ground_color = Color(0.45, 0.36, 0.28)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.ssao_enabled = true
	_env.ssao_radius = 1.5
	_env.ssao_intensity = 1.5
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_density = 0.00025
	_env.fog_sun_scatter = 0.25
	_env.fog_aerial_perspective = 0.6
	_env.volumetric_fog_enabled = false
	_env.glow_enabled = true
	_env.glow_intensity = 0.25
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 150.0
	_sun.light_angular_distance = 0.53
	add_child(_sun)


## Solar position for Tucson's latitude on `day_of_year`, local solar time.
func set_time_of_day(hours: float) -> void:
	time_of_day = hours
	var decl := deg_to_rad(23.44) * sin(TAU * (284 + day_of_year) / 365.0)
	var lat := deg_to_rad(LATITUDE)
	var hour_angle := deg_to_rad(15.0 * (hours - 12.0))
	var alt := asin(sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(hour_angle))
	var az := atan2(-sin(hour_angle), tan(decl) * cos(lat) - sin(lat) * cos(hour_angle))  # from north, clockwise
	# Direction the light travels (from sun to ground), +x east, -z north.
	var to_sun := Vector3(sin(az) * cos(alt), sin(alt), -cos(az) * cos(alt))
	_sun.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	var alt_deg := rad_to_deg(alt)
	# Warmer, dimmer light near the horizon.
	var warm := clampf(1.0 - alt_deg / 25.0, 0.0, 1.0)
	_sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.72, 0.45), warm)
	_sun.light_energy = lerpf(1.8, 1.1, warm) * clampf(alt_deg / 3.0, 0.0, 1.0)
	_env.ambient_light_energy = lerpf(1.0, 0.7, warm)
