shader_type canvas_item;

// Насколько глубоко тень заходит на экран (больше = глубже к центру)
uniform float reach : hint_range(0.1, 1.5) = 0.8;
// Общая прозрачность эффекта (меньше = незаметнее)
uniform float intensity : hint_range(0.0, 1.0) = 0.4;
// Цвет тени
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// 1. Вычисляем "параболу" для каждой оси.
	// Значение UV * (1.0 - UV) равно 0.0 на краях и 0.25 точно в центре.
	vec2 uv_curve = UV * (1.0 - UV);

	// 2. Перемножаем X и Y.
	// Это дает нам "карту", где центр самый яркий, а ЛЮБОЙ край черный.
	// Умножаем на константу (например 16.0), чтобы нормализовать центр ближе к 1.0.
	float base_vignette = uv_curve.x * uv_curve.y * 16.0;

	// 3. Инвертируем и применяем степень для мягкости.
	// (1.0 - base_vignette) делает края белыми (1.0), а центр черным (0.0).
	// Функция pow(x, reach) управляет кривизной спада. Чем выше 'reach', тем быстрее спад.
	float vignette_final = pow(1.0 - base_vignette, reach);

	// 4. Применяем итоговый цвет и интенсивность.
	// Умножаем альфу на vignette_final и на общую intensity.
	COLOR = vec4(color.rgb, vignette_final * intensity * color.a);
}