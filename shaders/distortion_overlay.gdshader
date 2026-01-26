shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.75;
uniform float squash_amount : hint_range(0.0, 0.2) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.6;
uniform float noise_scale : hint_range(1.0, 120.0) = 48.0;
uniform float chroma_shift : hint_range(0.0, 0.02) = 0.006;
uniform float color_shift : hint_range(0.0, 0.6) = 0.18;
uniform float warp_strength : hint_range(0.0, 0.02) = 0.008;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5);
	vec2 scale = vec2(1.0 - (squash_amount * 0.5), 1.0 + squash_amount);
	vec2 squash_uv = (uv - center) * scale + center;
	squash_uv = clamp(squash_uv, vec2(0.0), vec2(1.0));
	float t = TIME * 0.8;
	float noise = rand(uv * noise_scale + t);
	float wave = sin((uv.y * 18.0) + t * 2.5) * 0.5 + 0.5;
	vec2 warp = vec2(
		sin(t + uv.y * 12.0),
		cos(t * 1.2 + uv.x * 12.0)
	) * warp_strength * intensity;

	float shift = chroma_shift * intensity;
	vec3 col_r = texture(screen_texture, squash_uv + warp + vec2(shift, 0.0)).rgb;
	vec3 col_g = texture(screen_texture, squash_uv + warp - vec2(shift, 0.0)).rgb;
	vec3 col_b = texture(screen_texture, squash_uv + warp).rgb;
	vec3 distorted = vec3(col_r.r, col_g.g, col_b.b);
	distorted += (noise - 0.5) * color_shift * intensity;
	distorted *= mix(0.95, 1.1, wave * intensity);

	vec3 base = texture(screen_texture, squash_uv).rgb;
	float mix_amount = clamp(intensity, 0.0, 1.0);
	vec3 final_color = mix(base, distorted, mix_amount);
	COLOR = vec4(final_color, alpha * mix_amount);
}
