shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(2.0, 40.0) = 22.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float i = clamp(intensity, 0.0, 1.0);
	vec3 base = texture(screen_texture, uv).rgb;

	float pulse_fast = 0.5 + 0.5 * sin(TIME * pulse_speed + uv.y * 16.0);
	float pulse_slow = 0.5 + 0.5 * sin(TIME * (pulse_speed * 0.35) + uv.x * 9.0);

	float saturation = mix(1.0, mix(0.18, 2.1, pulse_fast), i);
	vec3 gray = vec3(dot(base, vec3(0.299, 0.587, 0.114)));
	vec3 saturated = gray + (base - gray) * saturation;

	float contrast = mix(1.0, mix(0.85, 1.35, pulse_slow), i * 0.9);
	vec3 contrasted = (saturated - 0.5) * contrast + 0.5;
	vec3 pain_tinted = contrasted * vec3(1.06, 0.92, 0.98);

	vec3 final_rgb = mix(base, clamp(pain_tinted, 0.0, 1.0), i);
	COLOR = vec4(final_rgb, 1.0);
}
