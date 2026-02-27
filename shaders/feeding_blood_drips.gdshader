shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 blood_color : source_color = vec4(0.78, 0.04, 0.03, 0.95);
uniform float speed : hint_range(0.1, 3.0) = 0.75;
uniform float thickness : hint_range(0.02, 0.35) = 0.1;
uniform float trail_length : hint_range(0.08, 0.95) = 0.5;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
uniform float seed : hint_range(0.0, 16.0) = 0.0;

float hash(float p) {
	return fract(sin((p + seed) * 127.1) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float alpha = 0.0;

	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float x = hash(fi + 0.17);
		float width = thickness * mix(0.55, 1.35, hash(fi + 2.31));
		float lane = smoothstep(width, 0.0, abs(uv.x - x));
		float phase = hash(fi + 4.12);
		float head = 0.06 + fract(t * mix(0.75, 1.35, hash(fi + 6.44)) + phase) * 0.94;
		float tail = trail_length * mix(0.45, 1.1, hash(fi + 8.86));
		float trail = step(uv.y, head) * step(head - tail, uv.y);
		float drop = smoothstep(width * 1.2, 0.0, distance(uv, vec2(x, head)));
		alpha += lane * trail * 0.33;
		alpha += drop * 0.9;
	}

	float top_noise = 0.5 + 0.5 * sin((uv.x + seed * 0.17) * 31.0 + sin((uv.x + seed) * 57.0) * 1.2);
	float top_start = mix(0.01, 0.1, top_noise);
	float top_fade = smoothstep(top_start, top_start + 0.16, uv.y);
	float side_fade = smoothstep(0.0, 0.03, uv.x) * smoothstep(0.0, 0.03, 1.0 - uv.x);
	float bottom_fade = smoothstep(1.0, 0.72, uv.y);

	alpha *= top_fade * side_fade * bottom_fade;
	alpha = clamp(alpha, 0.0, 1.0) * opacity;
	COLOR = vec4(blood_color.rgb, blood_color.a * alpha);
}
