shader_type canvas_item;

uniform float fade_width : hint_range(0.01, 0.8) = 0.24;

void fragment() {
	vec4 base_color = COLOR;
	float alpha_fade = smoothstep(0.0, fade_width, UV.x);
	COLOR = vec4(base_color.rgb, base_color.a * alpha_fade);
}
