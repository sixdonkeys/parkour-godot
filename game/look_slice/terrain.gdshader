shader_type spatial;
// Desert terrain (decision lighting): three CC0 scanned layers blended by
// slope, rock projected from three axes on steep ground, the baked sky
// occlusion from the landforms generator, and low-frequency variation so
// tiling doesn't show at distance.

uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_rough : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocky_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocky_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocky_rough : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_rough : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sky_ao : hint_default_white, filter_linear;
uniform float ground_scale = 0.25;   // repeats per metre (4 m tile)
uniform float rocky_scale = 0.2;
uniform float cliff_scale = 0.08;
uniform float rocky_from_deg = 14.0;
uniform float cliff_from_deg = 32.0;
uniform float roam_size = 1024.0;
uniform vec3 tint = vec3(1.0);

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

vec3 triplanar(sampler2D t, vec3 p, vec3 w, float s) {
	return texture(t, p.zy * s).rgb * w.x + texture(t, p.xz * s).rgb * w.y + texture(t, p.xy * s).rgb * w.z;
}

void fragment() {
	float slope = degrees(acos(clamp(world_nrm.y, 0.0, 1.0)));
	float w_rocky = smoothstep(rocky_from_deg - 6.0, rocky_from_deg + 6.0, slope);
	float w_cliff = smoothstep(cliff_from_deg - 6.0, cliff_from_deg + 6.0, slope);
	// Break up the transitions and the tiling with low-frequency noise.
	float macro = vnoise(world_pos.xz * 0.02) * 0.6 + vnoise(world_pos.xz * 0.11) * 0.4;
	w_rocky = clamp(w_rocky + (macro - 0.5) * 0.5, 0.0, 1.0);
	vec2 uvg = world_pos.xz * ground_scale + vec2(vnoise(world_pos.xz * 0.05)) * 0.3;
	vec3 g_alb = texture(ground_albedo, uvg).rgb;
	vec3 g_nrm = texture(ground_normal, uvg).rgb;
	float g_r = texture(ground_rough, uvg).r;
	vec2 uvr = world_pos.xz * rocky_scale;
	vec3 r_alb = texture(rocky_albedo, uvr).rgb;
	vec3 r_nrm = texture(rocky_normal, uvr).rgb;
	float r_r = texture(rocky_rough, uvr).r;
	vec3 bw = pow(abs(world_nrm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 c_alb = triplanar(cliff_albedo, world_pos, bw, cliff_scale);
	float c_r = triplanar(cliff_rough, world_pos, bw, cliff_scale).r;
	vec3 alb = mix(mix(g_alb, r_alb, w_rocky), c_alb, w_cliff);
	vec3 nrm = mix(g_nrm, r_nrm, w_rocky);
	float rough = mix(mix(g_r, r_r, w_rocky), c_r, w_cliff);
	alb *= mix(0.88, 1.08, macro) * tint;
	vec2 ao_uv = (world_pos.xz + vec2(roam_size * 0.5)) / roam_size;
	float ao = texture(sky_ao, ao_uv).r;
	ALBEDO = alb;
	NORMAL_MAP = mix(nrm, vec3(0.5, 0.5, 1.0), w_cliff * 0.7);
	ROUGHNESS = rough;
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
}
