shader_type canvas_item;

uniform sampler2D under_texture : source_color;
uniform float tear_width : hint_range(0.05, 0.5) = 0.24;
uniform float edge_roughness : hint_range(0.0, 0.3) = 0.11;
uniform float edge_noise_scale : hint_range(2.0, 80.0) = 22.0;
uniform float hole_density : hint_range(0.0, 1.0) = 0.48;
uniform float hole_noise_scale : hint_range(5.0, 120.0) = 56.0;
uniform float edge_softness : hint_range(0.001, 0.06) = 0.015;
uniform float edge_darkening : hint_range(0.0, 1.0) = 0.28;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise2d(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec4 front = texture(TEXTURE, UV);
	vec4 under = texture(under_texture, UV);

	float rough = (fbm(vec2(UV.y * edge_noise_scale, 0.0)) - 0.5) * 2.0;
	float cut_x = 1.0 - tear_width + rough * edge_roughness;

	// Main tear from the right side.
	float torn_strip = smoothstep(cut_x - edge_softness, cut_x + edge_softness, UV.x);

	// Additional irregular "bites" near the tear edge.
	float hole_noise = fbm(UV * hole_noise_scale + vec2(0.0, UV.y * 8.0));
	float near_edge = smoothstep(cut_x - (tear_width * 0.35), cut_x + edge_softness, UV.x);
	float holes = step(1.0 - hole_density, hole_noise) * near_edge;
	float reveal = clamp(max(torn_strip, holes), 0.0, 1.0);

	vec3 mixed_color = mix(front.rgb, under.rgb, reveal);

	// Darken the paper edge slightly for a torn look.
	float paper_edge = (1.0 - smoothstep(0.0, edge_softness * 4.0, abs(UV.x - cut_x))) * (1.0 - reveal);
	mixed_color *= 1.0 - paper_edge * edge_darkening;

	COLOR = vec4(mixed_color, front.a);
}
