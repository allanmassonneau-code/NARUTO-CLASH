shader_type sky;
// Anime sky: zenith/horizon gradient (from the SS height-fog inscattering colours of the
// preset), flat two-tone clouds and a hard sun disc.

uniform vec4 zenith_color : source_color = vec4(0.25, 0.5, 0.88, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.7, 0.83, 0.93, 1.0);
uniform vec4 ground_color : source_color = vec4(0.35, 0.42, 0.38, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.72, 0.79, 0.92, 1.0);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_scale = 1.6;
uniform float sun_size = 0.9996;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col = mix(horizon_color.rgb, zenith_color.rgb, smoothstep(0.0, 0.6, d.y));
	if (d.y < 0.0) {
		col = mix(horizon_color.rgb, ground_color.rgb, smoothstep(0.0, -0.2, d.y));
	} else {
		vec2 uv = d.xz / (d.y + 0.2) * cloud_scale;
		float n = fbm(uv);
		float lit_side = fbm(uv - LIGHT0_DIRECTION.xz * 0.06);
		float cover = smoothstep(cloud_coverage, cloud_coverage + 0.025, n) * smoothstep(0.0, 0.15, d.y);
		vec3 cloud = mix(cloud_shade.rgb, cloud_color.rgb, smoothstep(cloud_coverage + 0.04, cloud_coverage + 0.07, lit_side));
		col = mix(col, cloud, cover);
	}
	if (LIGHT0_ENABLED) {
		float s = dot(d, LIGHT0_DIRECTION);
		col = mix(col, vec3(1.0, 0.98, 0.92) * 1.4, smoothstep(sun_size, sun_size + 0.0002, s));
		col += LIGHT0_COLOR * pow(max(s, 0.0), 80.0) * 0.12;
	}
	COLOR = col;
}
