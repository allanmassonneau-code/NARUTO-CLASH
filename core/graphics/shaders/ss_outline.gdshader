shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, ambient_light_disabled;
// Inverted-hull character outline, port of Shinobi Striker's /Game/NarutoShading/M_Line:
// the hull is pushed along the normals by a width that follows the camera distance and FOV
// (constant on-screen thickness), damped by DistanceScale (-0.1 in SS) so far fighters get
// slightly thinner lines, and divided by the object scale.

uniform vec4 outline_color : source_color = vec4(0.1, 0.08, 0.08, 1.0);
// Fraction of the half screen height.
uniform float width = 0.0032;
uniform float distance_scale = -0.1;  // SS M_Line DistanceScale
uniform float reference_distance = 10.0;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = max(length(INV_VIEW_MATRIX[3].xyz - world_pos), 0.05);
	float tan_half_fov = 1.0 / PROJECTION_MATRIX[1][1];
	float w = width * dist * tan_half_fov * pow(dist / reference_distance, distance_scale);
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += normalize(NORMAL) * w / max(scale, vec3(0.001));
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
