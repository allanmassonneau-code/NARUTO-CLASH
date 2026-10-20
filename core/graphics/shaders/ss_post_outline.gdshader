shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, ambient_light_disabled, fog_disabled;
// Screen-space line pass, port of Shinobi Striker's post-process outline
// (M_N1Outline_code / MI_N1OutlineEnv_*): dark lines on depth breaks and on normal
// creases above ENV_Threshold, fading out between ENV_Alpha_NFP near / far.
// Drawn by a full-screen quad parented to the camera (SSGraphics.attach_post_outline).

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest, repeat_disable;
// SS ENV_OutlineColor (linear 0.01, 0.006, 0.005).
uniform vec4 line_color : source_color = vec4(0.1, 0.075, 0.07, 1.0);
uniform float thickness = 1.0;
// Relative depth jump that starts a line, and how fast it saturates.
uniform float depth_threshold = 0.035;
uniform float depth_sensitivity = 14.0;
uniform float normal_threshold_min = 0.4;  // SS ENV_ThresholdMin
uniform float normal_threshold_max = 0.5;  // SS ENV_ThresholdMax
uniform float fade_near = 80.0;   // SS ENV_Alpha_NFP 8000 cm
uniform float fade_far = 200.0;   // SS ENV_Alpha_NFP 20000 cm
uniform float max_alpha : hint_range(0.0, 1.0) = 0.85;
// Crease lines (normals) only up close: on far foliage cards they turn into noise.
uniform float crease_fade_near = 22.0;
uniform float crease_fade_far = 40.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_projection) {
	float d = texture(depth_texture, uv).r;
	vec4 v = inv_projection * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_texture, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	vec2 offsets[4] = {vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y)};
	float dc = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 nc = view_normal(SCREEN_UV);
	float jump = 0.0;
	float crease = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offsets[i];
		// Only the nearer side of a depth break draws: lines hug the front silhouette.
		jump = max(jump, view_depth(uv, INV_PROJECTION_MATRIX) - dc);
		crease = max(crease, 1.0 - dot(nc, view_normal(uv)));
	}
	float depth_edge = clamp((jump / max(dc, 0.01) - depth_threshold) * depth_sensitivity, 0.0, 1.0);
	float normal_edge = smoothstep(normal_threshold_min, normal_threshold_max, crease) * (1.0 - smoothstep(crease_fade_near, crease_fade_far, dc));
	float fade = 1.0 - smoothstep(fade_near, fade_far, dc);
	ALBEDO = line_color.rgb;
	ALPHA = max(depth_edge, normal_edge) * fade * max_alpha;
}
