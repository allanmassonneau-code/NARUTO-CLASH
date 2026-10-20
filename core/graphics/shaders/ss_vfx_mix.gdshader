shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Shinobi Striker effect sprites (local T_EFF_* flipbooks: fire, smoke, lightning, wind...):
// one flipbook cell per frame, camera-facing or laid on the ground. Alpha-blended variant (smoke,
// rock, dust): opaque matter, no glow.

uniform sampler2D flipbook : filter_linear_mipmap, hint_default_black;
uniform ivec2 grid = ivec2(1, 1);
uniform float emission = 1.0;
uniform bool billboard = true;
instance uniform float frame = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float spin = 0.0;

void vertex() {
	if (billboard) {
		vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x, INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 c = UV - 0.5;
	float cs = cos(spin), sn = sin(spin);
	vec2 uv = clamp(vec2(c.x * cs - c.y * sn, c.x * sn + c.y * cs) + 0.5, 0.0, 1.0);
	int cells = max(grid.x * grid.y, 1);
	int f = int(frame) % cells;
	vec2 cell = vec2(float(f % grid.x), float(f / grid.x));
	float m = texture(flipbook, (cell + uv) / vec2(grid)).r;
	ALBEDO = tint.rgb * emission;
	ALPHA = clamp(m * tint.a * fade, 0.0, 1.0);
}
