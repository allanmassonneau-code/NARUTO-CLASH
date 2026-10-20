shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Shinobi Striker character material for the real SS meshes (local assets): the mesh UVs
// point into the game's palette atlases, BC_Map gives the lit colour and SC_Map the shadow
// colour of the same swatch (M_CustChara / MSM_NarutoShadeChr), split on a hard threshold,
// with the SS UC brush and the lit rim. Faces without a texture use Skin_BC / Skin_SC.

uniform sampler2D bc_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D sc_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform bool use_bc_map = true;
uniform bool use_sc_map = true;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.75, 0.55, 0.45, 1.0);
uniform bool alpha_clip = false;
// Creator parts tinted by ColorMask_RGB have no tinted SC map: derive the shadow from the lit
// colour (fit on SS Skin/Hair/Costume BC->SC pairs, linear: SC ~ BC^1.9 kept warm).
uniform bool derive_shade = false;
// SS environment materials (M_ENV_BaseShader): AA_BaseMixColor tints the grey BC maps, AA_ShadowColor
// tints the shadow side. Linear values (may exceed 1), so no source_color hint.
uniform vec3 mix_color = vec3(1.0);
uniform vec3 shadow_mix = vec3(1.0);
// SS character creator: ColorMask_RGB tints the untinted palette (R skin, G colour 0, B colour 1),
// like the game: v *= 1 + mask_k * (colour_k - 1) for each channel.
uniform bool use_mask = false;
uniform sampler2D mask_map : filter_linear_mipmap, hint_default_black;
uniform vec4 tint_skin : source_color = vec4(1.0);
uniform vec4 tint_color0 : source_color = vec4(1.0);
uniform vec4 tint_color1 : source_color = vec4(1.0);

// Ground / tiling surfaces: sample the SS maps in world space (metres per repeat).
// SS face paint (MI_CHR_FacePaint_*): FacePaint_Map mask placed on the face UV by FacePaint_UV
// on the face's second UV set (centre in 1/256 of the UV square, size as a fraction of it) and FacePaint_Rot (turns).
uniform bool use_paint = false;
uniform sampler2D paint_map : filter_linear_mipmap, hint_default_black;
uniform vec4 paint_rect = vec4(128.0, 128.0, 0.2, 0.2);
uniform float paint_rot = 0.0;
// Second copy (FacePaint_UVOffset, when its size is set below 1).
uniform bool use_paint2 = false;
uniform vec4 paint_rect2 = vec4(165.0, 175.0, 0.2, 0.2);
uniform vec4 paint_color : source_color = vec4(0.5, 0.05, 0.06, 1.0);

uniform bool world_uv = false;
uniform float uv_tile = 6.0;
varying vec2 v_world_xz;

uniform sampler2D uc_texture : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float uc_scale = 4.0;
uniform float uc_contrast_shadow = 0.5;
uniform float hatch_strength = 0.25;
uniform float threshold : hint_range(0.0, 1.0) = 0.54;
uniform float softness : hint_range(0.001, 0.2) = 0.012;
uniform float rim_strength = 0.3;
uniform float rim_power = 5.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);

varying vec3 v_shade_ratio;
varying float v_hatch;

void vertex() {
	v_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = world_uv ? v_world_xz / uv_tile : UV;
	vec4 bc = use_bc_map ? texture(bc_map, uv) * base_color : base_color;
	bc.rgb *= mix_color;
	vec3 tint = vec3(1.0);
	if (use_mask) {
		vec3 w = texture(mask_map, uv).rgb;
		tint = (1.0 + w.r * (tint_skin.rgb - 1.0)) * (1.0 + w.g * (tint_color0.rgb - 1.0)) * (1.0 + w.b * (tint_color1.rgb - 1.0));
		bc.rgb *= tint;
	}
	float paint = 0.0;
	if (use_paint) {
		vec2 d = (UV2 - paint_rect.xy / 256.0) / max(paint_rect.zw, vec2(0.001));
		float a = paint_rot * 6.2831853;
		d = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * d + 0.5;
		if (d.x >= 0.0 && d.x <= 1.0 && d.y >= 0.0 && d.y <= 1.0) {
			paint = texture(paint_map, d).r;
		}
		if (use_paint2) {
			vec2 d2 = (UV2 - paint_rect2.xy / 256.0) / max(paint_rect2.zw, vec2(0.001));
			d2 = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * d2 + 0.5;
			if (d2.x >= 0.0 && d2.x <= 1.0 && d2.y >= 0.0 && d2.y <= 1.0) {
				paint = max(paint, texture(paint_map, d2).r);
			}
		}
		bc.rgb = mix(bc.rgb, paint_color.rgb, paint);
	}
	vec3 sc = use_sc_map ? texture(sc_map, uv).rgb : shade_color.rgb;
	if (use_paint) {
		sc = mix(sc, paint_color.rgb * 0.7, paint);
	}
	if (derive_shade) {
		sc = pow(bc.rgb, vec3(1.9)) * vec3(1.0, 0.92, 0.95);
	}
	sc *= shadow_mix;
	if (use_mask && use_sc_map) {
		sc *= tint;
	}
	if (alpha_clip && bc.a < 0.5) {
		discard;
	}
	vec3 ratio = clamp(sc / max(bc.rgb, vec3(0.002)), vec3(0.0), vec3(1.5));
	vec4 uc = texture(uc_texture, uv * uc_scale);
	ratio *= 1.0 + (uc.b - 0.47) * 0.45 * uc_contrast_shadow;
	v_shade_ratio = ratio;
	v_hatch = uc.g * hatch_strength;
	ALBEDO = bc.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = smoothstep(threshold - softness, threshold + softness, ndl * 0.5 + 0.5);
		lit *= smoothstep(0.3, 0.7, ATTENUATION);
		vec3 shade = v_shade_ratio * (1.0 - v_hatch * (1.0 - lit));
		DIFFUSE_LIGHT += mix(shade, vec3(1.0), lit) * LIGHT_COLOR / PI;
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
		SPECULAR_LIGHT += smoothstep(0.3, 0.42, fresnel) * lit * rim_strength * rim_color.rgb * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += smoothstep(0.0, 0.08, ndl) * ATTENUATION * 0.8 * LIGHT_COLOR / PI;
	}
}
