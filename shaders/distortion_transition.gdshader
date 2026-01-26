shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.85;
uniform float flow_scale : hint_range(1.0, 40.0) = 12.0;
uniform float warp_strength : hint_range(0.0, 0.08) = 0.045;
uniform float smear_strength : hint_range(0.0, 0.05) = 0.02;
uniform float chroma_shift : hint_range(0.0, 0.03) = 0.012;
uniform float squash_amount : hint_range(0.0, 0.2) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5);
	vec2 scale = vec2(1.0 - (squash_amount * 0.5), 1.0 + squash_amount);
	vec2 base_uv = (uv - center) * scale + center;
	base_uv = clamp(base_uv, vec2(0.0), vec2(1.0));
	float t = TIME * 1.3;

	float flow_x = sin((base_uv.y + t) * flow_scale) + sin((base_uv.y - t * 1.7) * (flow_scale * 0.6));
	float flow_y = cos((base_uv.x - t * 0.9) * (flow_scale * 0.8)) + sin((base_uv.x + t * 1.2) * (flow_scale * 0.7));
	vec2 flow = vec2(flow_x, flow_y) * warp_strength * intensity;

	float smear = sin((base_uv.x + base_uv.y + t) * 6.0) * 0.5 + 0.5;
	vec2 wobble = vec2(
		sin(t + base_uv.y * 12.0),
		cos(t * 1.1 + base_uv.x * 12.0)
	) * smear_strength * smear * intensity;

	vec2 warped_uv = base_uv + flow + wobble;
	warped_uv = clamp(warped_uv, vec2(0.0), vec2(1.0));

	float shift = chroma_shift * intensity;
	vec3 col_r = texture(screen_texture, warped_uv + vec2(shift, 0.0)).rgb;
	vec3 col_g = texture(screen_texture, warped_uv - vec2(shift, 0.0)).rgb;
	vec3 col_b = texture(screen_texture, warped_uv + vec2(0.0, shift)).rgb;
	vec3 distorted = vec3(col_r.r, col_g.g, col_b.b);

	vec3 base = texture(screen_texture, base_uv).rgb;
	float mix_amount = clamp(intensity * 1.1, 0.0, 1.0);
	vec3 final_color = mix(base, distorted, mix_amount);
	COLOR = vec4(final_color, alpha * mix_amount);
}
