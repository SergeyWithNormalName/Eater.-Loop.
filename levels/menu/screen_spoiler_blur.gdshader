shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_strength : hint_range(0.0, 1.0) = 1.0;
uniform float blur_lod : hint_range(0.0, 6.0) = 2.8;
uniform float tint_strength : hint_range(0.0, 0.5) = 0.22;
uniform vec3 tint_color = vec3(0.01, 0.03, 0.08);

void fragment() {
	vec3 sharp = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	vec3 blurred = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	vec3 mixed = mix(sharp, blurred, blur_strength);
	mixed = mix(mixed, tint_color, tint_strength);
	COLOR = vec4(mixed, 1.0);
}
