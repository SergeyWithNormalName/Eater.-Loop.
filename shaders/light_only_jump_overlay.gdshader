shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float noise_speed : hint_range(0.0, 80.0) = 30.0;
uniform float glitch_amount : hint_range(0.0, 0.4) = 0.08;

float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	float offset = (random(vec2(TIME * 15.0, SCREEN_UV.y)) - 0.5) * glitch_amount * intensity;
	vec2 glitched_uv = SCREEN_UV + vec2(offset, 0.0);
	glitched_uv = clamp(glitched_uv, vec2(0.0), vec2(1.0));

	vec4 screen_color = texture(screen_texture, glitched_uv);

	float noise = random(SCREEN_UV + vec2(TIME * noise_speed));
	noise = step(0.85 - (intensity * 0.2), noise);

	vec3 dark_void = vec3(0.03, 0.0, 0.02);
	vec3 noise_color = vec3(noise);
	vec3 scary_overlay = mix(dark_void, noise_color, noise * (0.5 + intensity * 0.5));

	COLOR.rgb = mix(screen_color.rgb, scary_overlay, intensity);
	COLOR.a = 1.0;
}
