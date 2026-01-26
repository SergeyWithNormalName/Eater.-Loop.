shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Основной параметр перехода (0.0 - нет эффекта, 1.0 - полный кошмар)
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// Настройки эффекта
uniform float shake_power : hint_range(0.0, 0.1) = 0.03; // Сила тряски
uniform float color_bleeding : hint_range(0.0, 0.5) = 0.05; // Сила расслоения цветов
uniform float glitch_lines : hint_range(0.0, 100.0) = 50.0; // Количество полос глитча
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.8; // Темнота по краям
uniform float noise_quality : hint_range(100.0, 500.0) = 250.0; // Зернистость

float rand(vec2 co) {
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float noise(vec2 uv, float time) {
	vec2 i = floor(uv * noise_quality);
	vec2 f = fract(uv * noise_quality);
	float a = rand(i + vec2(time));
	return a;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// 1. Глитч и тряска
	float slit = floor(uv.y * glitch_lines + TIME * 10.0);
	float glitch_offset = (rand(vec2(slit, floor(TIME * 20.0))) - 0.5) * intensity * 0.1;
	
	vec2 shake = vec2(
		(rand(vec2(TIME * 15.0, 0.0)) - 0.5) * shake_power * intensity,
		(rand(vec2(0.0, TIME * 12.0)) - 0.5) * shake_power * intensity
	);
	
	vec2 distorted_uv = clamp(uv + vec2(glitch_offset, 0.0) + shake, 0.0, 1.0);

	// 2. Хроматическая аберрация
	float aberration_amount = color_bleeding * intensity * (1.0 + length(uv - 0.5));
	
	float r = texture(screen_texture, distorted_uv + vec2(aberration_amount, 0.0)).r;
	float g = texture(screen_texture, distorted_uv + vec2(0.0, noise(uv, TIME) * 0.005 * intensity)).g;
	float b = texture(screen_texture, distorted_uv - vec2(aberration_amount, 0.0)).b;
	
	vec3 final_color = vec3(r, g, b);

	// 3. Шум
	float grain = noise(uv, TIME);
	final_color = mix(final_color, final_color * grain, intensity * 0.3);

	// 4. Виньетка
	float dist_from_center = distance(uv, vec2(0.5));
	float vignette = 1.0 - (dist_from_center * vignette_intensity * intensity * 1.5);
	vignette = clamp(vignette, 0.0, 1.0);
	float flicker = 1.0 - (rand(vec2(TIME)) * 0.2 * intensity);
	final_color *= vignette * flicker;
	
	// 5. Инверсия (вспышка)
	if (intensity > 0.8) {
		float flash = (intensity - 0.8) * 5.0;
		final_color = mix(final_color, vec3(1.0) - final_color, flash * rand(vec2(TIME)));
	}

	// ИСПРАВЛЕНИЕ: Используем intensity как Alpha канал.
	// Когда эффект ослабевает (intensity -> 0), этот слой становится прозрачным,
	// и становится виден нижний слой (постоянное искажение).
	COLOR = vec4(final_color, intensity);
}

