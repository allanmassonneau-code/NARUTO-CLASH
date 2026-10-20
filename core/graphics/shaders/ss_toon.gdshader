shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Shared toon shader (characters, props, ground), a Godot port of Shinobi Striker's
// MSM_NarutoShadeChr shading model (M_CustChara / MI_CHR_Base):
// - two flat tones: BC (lit) and SC (shadow), split on a hard threshold;
// - a tiling "UC" brush texture (T_SHD_TypeD_UC) that breaks the shadow into painted
//   patches (R/B) and hatching strokes (G);
// - a thin banded rim on the lit side (SS "spec outline").
// Use SSGraphics to build materials: it fills shade_color from base_color with the
// BC -> SC pairs measured on SS textures.

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.7, 0.55, 0.5, 1.0);
uniform bool use_vertex_color = false;

// Optional surface texture (SS environment BC maps), triplanar, normalised by its mean so
// it adds SS detail while base_color keeps the hue.
uniform bool use_albedo_texture = false;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec3 albedo_mean = vec3(0.5);
uniform float texture_scale = 0.25;
uniform float texture_detail : hint_range(0.0, 1.5) = 1.0;
// Static props sample in world space (continuous across pieces); characters in object space.
uniform bool world_space = false;

uniform sampler2D uc_texture : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float uc_scale = 1.5;
uniform float uc_contrast = 0.8;         // SS UC_Contrast
uniform float uc_contrast_shadow = 0.5;  // SS UC_Contrast_Shadow
uniform float hatch_strength = 0.3;

uniform float threshold : hint_range(0.0, 1.0) = 0.54;  // SS Thickness_Threshold_Rough.y
uniform float softness : hint_range(0.001, 0.2) = 0.012;
uniform float rim_strength = 0.3;
uniform float rim_power = 5.0;  // SS CH_SpecOutlinePower
uniform vec4 rim_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float local_light_strength = 0.8;
// Grass / flat foliage: shade like the ground they stand on (no speckled terminator).
uniform bool up_normals = false;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec3 v_shade_ratio;
varying float v_hatch;

vec3 triplanar_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 0.0001);
}

// Two samplers with different hints: Godot needs one helper per sampler setting.
vec4 triplanar_albedo(vec3 p, vec3 n) {
	vec3 w = triplanar_weights(n);
	return texture(albedo_texture, p.zy) * w.x + texture(albedo_texture, p.xz) * w.y + texture(albedo_texture, p.xy) * w.z;
}

vec4 triplanar_uc(vec3 p, vec3 n) {
	vec3 w = triplanar_weights(n);
	return texture(uc_texture, p.zy) * w.x + texture(uc_texture, p.xz) * w.y + texture(uc_texture, p.xy) * w.z;
}

void vertex() {
	if (up_normals) {
		NORMAL = normalize(vec3(0.0, 1.0, 0.0) * mat3(MODEL_MATRIX));
	}
	if (world_space) {
		v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	} else {
		v_pos = VERTEX;
		v_nrm = NORMAL;
	}
}

void fragment() {
	vec3 bc = base_color.rgb;
	vec3 sc = shade_color.rgb;
	if (use_vertex_color) {
		bc *= COLOR.rgb;
		sc *= COLOR.rgb;
	}
	if (use_albedo_texture) {
		vec3 t = triplanar_albedo(v_pos * texture_scale, v_nrm).rgb;
		vec3 detail = mix(vec3(1.0), t / max(albedo_mean, vec3(0.04)), texture_detail);
		bc *= detail;
		sc *= detail;
	}
	vec3 ratio = clamp(sc / max(bc, vec3(0.002)), vec3(0.0), vec3(1.5));
	vec4 uc = triplanar_uc(v_pos * uc_scale, v_nrm);
	// T_SHD_TypeD_UC means: R 0.67, B 0.47 (patches); G = hatching strokes.
	bc *= 1.0 + (uc.r - 0.67) * 0.22 * uc_contrast;
	ratio *= 1.0 + (uc.b - 0.47) * 0.45 * uc_contrast_shadow;
	v_shade_ratio = ratio;
	v_hatch = uc.g * hatch_strength;
	ALBEDO = bc;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	EMISSION = emission_color.rgb * emission_energy;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float half_lambert = ndl * 0.5 + 0.5;
		float lit = smoothstep(threshold - softness, threshold + softness, half_lambert);
		lit *= smoothstep(0.3, 0.7, ATTENUATION);  // received shadows are hard too
		vec3 shade = v_shade_ratio * (1.0 - v_hatch * (1.0 - lit));
		DIFFUSE_LIGHT += mix(shade, vec3(1.0), lit) * LIGHT_COLOR / PI;
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
		SPECULAR_LIGHT += smoothstep(0.3, 0.42, fresnel) * lit * rim_strength * rim_color.rgb * LIGHT_COLOR / PI;
	} else {
		float lit = smoothstep(0.0, 0.08, ndl) * ATTENUATION;
		DIFFUSE_LIGHT += lit * local_light_strength * LIGHT_COLOR / PI;
	}
}
