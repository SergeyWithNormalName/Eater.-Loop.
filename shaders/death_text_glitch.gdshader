shader_type canvas_item;
render_mode unshaded;

uniform float glitch_strength : hint_range(0.0, 1.0) = 0.9;
uniform float line_jitter : hint_range(0.0, 0.2) = 0.07;
uniform float chroma_shift : hint_range(0.0, 0.08) = 0.018;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
uniform float flicker_speed : hint_range(0.0, 40.0) = 14.0;
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.82, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * max(flicker_speed, 0.001);
	float line = floor(uv.y * 220.0 + t * 0.65);
	float line_noise = hash(vec2(line, floor(t * 0.5))) - 0.5;
	float jump_noise = hash(vec2(floor(t * 6.0), 7.31)) - 0.5;

	vec2 shifted_uv = uv;
	shifted_uv.x += line_noise * line_jitter * glitch_strength;
	shifted_uv.x += jump_noise * 0.03 * glitch_strength;
	shifted_uv = clamp(shifted_uv, vec2(0.0), vec2(1.0));

	float shift = chroma_shift * glitch_strength;
	float r = texture(TEXTURE, clamp(shifted_uv + vec2(shift, 0.0), vec2(0.0), vec2(1.0))).r;
	float g = texture(TEXTURE, shifted_uv).g;
	float b = texture(TEXTURE, clamp(shifted_uv - vec2(shift, 0.0), vec2(0.0), vec2(1.0))).b;
	float a = texture(TEXTURE, shifted_uv).a;

	vec3 color = vec3(r, g, b) * tint.rgb;
	float scanline = sin((uv.y + TIME * 2.4) * 1450.0) * 0.5 + 0.5;
	color *= 1.0 - scanline * scanline_strength * glitch_strength;

	float flicker = 0.72 + 0.28 * hash(vec2(floor(t * 2.0), 13.0));
	color *= flicker;

	float grain = hash(uv * 900.0 + vec2(TIME * 17.0, TIME * 11.0)) - 0.5;
	color += vec3(grain) * 0.14 * glitch_strength;

	COLOR = vec4(clamp(color, 0.0, 1.0), a * tint.a);
}
