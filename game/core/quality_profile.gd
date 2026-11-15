class_name QualityProfile
extends Resource
## Every setting that trades looks for speed (decision quality-profiles).
## Levels are authored at the highest quality they are meant to have; a
## profile only clamps down. A new tier is a new .tres file in res://profiles/.

@export var profile_name := "neo"

@export_group("Resolution")
## Fraction of the window's pixels the 3D world renders at.
@export_range(0.25, 1.0, 0.01) var render_scale := 0.75
## Upscalers in order of preference; the first the running driver supports is used.
## Names: "metalfx_temporal", "metalfx_spatial", "fsr2", "fsr", "bilinear".
@export var upscalers: PackedStringArray = ["metalfx_temporal", "fsr2", "bilinear"]

@export_group("Anti-aliasing")
@export var msaa_3d := Viewport.MSAA_DISABLED
## Used when the chosen upscaler isn't temporal.
@export var use_taa := true
@export var screen_space_aa := Viewport.SCREEN_SPACE_AA_DISABLED

@export_group("Geometry")
@export var mesh_lod_threshold := 1.0
## Multiplies the instance count levels scatter (rocks, plants, roof clutter).
@export_range(0.0, 1.0, 0.05) var scatter_density := 1.0
## Multiplies visibility ranges of scattered and backdrop instances.
@export_range(0.25, 2.0, 0.05) var draw_distance := 1.0

@export_group("Shadows")
@export var directional_shadow_size := 4096
@export_enum("1 split", "2 splits", "4 splits") var directional_shadow_splits := 2
@export var directional_shadow_max_distance := 150.0
@export var soft_shadow_quality := RenderingServer.SHADOW_QUALITY_SOFT_LOW
@export var positional_shadow_atlas_size := 2048

@export_group("Effect caps")
@export var allow_sdfgi := false
@export var sdfgi_ray_count := RenderingServer.ENV_SDFGI_RAY_COUNT_16
@export var gi_half_resolution := true
@export var allow_ssao := true
@export var ssao_quality := RenderingServer.ENV_SSAO_QUALITY_LOW
@export var allow_ssil := false
@export var allow_ssr := false
@export var ssr_max_steps := 32
@export var allow_volumetric_fog := true
@export var volumetric_fog_size := 64
@export var volumetric_fog_depth := 64
@export var allow_glow := true

@export_group("Textures")
## Folder suffix under res://assets/_tiers/ the asset resolver reads from;
## empty means source textures.
@export var texture_tier := "neo"

const _UPSCALER_MODES := {
	"bilinear": Viewport.SCALING_3D_MODE_BILINEAR,
	"fsr": Viewport.SCALING_3D_MODE_FSR,
	"fsr2": Viewport.SCALING_3D_MODE_FSR2,
	"metalfx_spatial": Viewport.SCALING_3D_MODE_METALFX_SPATIAL,
	"metalfx_temporal": Viewport.SCALING_3D_MODE_METALFX_TEMPORAL,
}

var chosen_upscaler := ""


func _upscaler_supported(upscaler_name: String) -> bool:
	var driver := RenderingServer.get_current_rendering_driver_name()
	var method := RenderingServer.get_current_rendering_method()
	match upscaler_name:
		"metalfx_temporal", "metalfx_spatial":
			return driver == "metal"
		"fsr2":
			return method == "forward_plus"
		"fsr", "bilinear":
			return true
	return false


func apply(viewport: Viewport, scene: Node = null) -> void:
	chosen_upscaler = "bilinear"
	for u in upscalers:
		if _upscaler_supported(u):
			chosen_upscaler = u
			break
	viewport.scaling_3d_mode = _UPSCALER_MODES[chosen_upscaler]
	viewport.scaling_3d_scale = render_scale
	var temporal_upscaler := chosen_upscaler in ["fsr2", "metalfx_temporal"]
	viewport.use_taa = use_taa and not temporal_upscaler
	viewport.msaa_3d = msaa_3d
	viewport.screen_space_aa = screen_space_aa
	viewport.mesh_lod_threshold = mesh_lod_threshold
	viewport.positional_shadow_atlas_size = positional_shadow_atlas_size
	RenderingServer.directional_shadow_atlas_set_size(directional_shadow_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(soft_shadow_quality)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft_shadow_quality)
	RenderingServer.gi_set_use_half_resolution(gi_half_resolution)
	RenderingServer.environment_set_ssao_quality(ssao_quality, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_sdfgi_ray_count(sdfgi_ray_count)
	RenderingServer.environment_set_volumetric_fog_volume_size(volumetric_fog_size, volumetric_fog_depth)
	if scene:
		apply_to_scene(scene)


## Clamp a loaded scene's environments and lights to this profile's caps.
func apply_to_scene(scene: Node) -> void:
	for n in _all(scene):
		if n is WorldEnvironment and n.environment:
			var env: Environment = n.environment
			env.sdfgi_enabled = env.sdfgi_enabled and allow_sdfgi
			env.ssao_enabled = env.ssao_enabled and allow_ssao
			env.ssil_enabled = env.ssil_enabled and allow_ssil
			env.ssr_enabled = env.ssr_enabled and allow_ssr
			env.ssr_max_steps = mini(env.ssr_max_steps, ssr_max_steps)
			env.volumetric_fog_enabled = env.volumetric_fog_enabled and allow_volumetric_fog
			env.glow_enabled = env.glow_enabled and allow_glow
		elif n is DirectionalLight3D:
			var l: DirectionalLight3D = n
			l.directional_shadow_max_distance = minf(l.directional_shadow_max_distance, directional_shadow_max_distance)
			l.directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL,
				DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
				DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][directional_shadow_splits]
		if n.is_in_group("quality_scaled") and n.has_method("apply_quality"):
			n.apply_quality(self)


func _all(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	var i := 0
	while i < out.size():
		out.append_array(out[i].get_children())
		i += 1
	return out


func describe() -> Dictionary:
	var d := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_STORAGE:
			d[p.name] = get(p.name)
	d["chosen_upscaler"] = chosen_upscaler
	return d
