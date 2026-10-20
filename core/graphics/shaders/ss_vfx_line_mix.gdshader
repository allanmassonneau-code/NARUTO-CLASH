shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Shinobi Striker tether / thread / chain: an SS pattern (trail, seal script) scrolled along
// a flat ribbon (UV.x = metres along the line, UV.y = across). Alpha-blended variant for dark
// elements (shadow, blood): additive would make them invisible.

uniform sampler2D pattern : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tile = 1.5;
uniform float scroll = 1.2;
uniform float emission = 1.0;

void fragment() {
	float m = texture(pattern, vec2(UV.x / tile - TIME * scroll, UV.y)).r;
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = tint.rgb * emission;
	ALPHA = clamp(m * smoothstep(0.0, 0.35, edge) * tint.a, 0.0, 1.0);
}
