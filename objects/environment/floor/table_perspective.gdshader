shader_type canvas_item;

// Базовая сила перспективного сжатия (для стола обычно ниже, чем у пола).
uniform float perspective_amount : hint_range(0.0, 4.0) = 0.55;
// Точка схода по X (0..1).
uniform float vanish_x : hint_range(0.0, 1.0) = 0.5;
// Горизонт в тех же координатах, что и у пола.
uniform float horizon : hint_range(-10.0, 1.0) = -3.73;
// Дополнительный масштаб по X.
uniform float x_scale : hint_range(0.2, 2.0) = 1.0;
// Сила эффекта у краев (в центре эффект можно ослабить).
uniform float edge_strength : hint_range(0.0, 2.0) = 1.0;
// Кривая нарастания эффекта у краев.
uniform float edge_power : hint_range(0.5, 6.0) = 2.0;
// Плоская зона около центра.
uniform float center_width : hint_range(0.0, 0.49) = 0.0;
// Где эффект достигает максимума.
uniform float edge_end : hint_range(0.01, 2.0) = 0.5;
// Ограничение глубины, чтобы не было экстремальных искажений.
uniform float max_distance : hint_range(1.0, 80.0) = 10.0;
// Насколько сильно сжимать верх стола (больше = сильнее).
uniform float vertical_power : hint_range(0.2, 4.0) = 1.35;

void fragment() {
	vec2 uv = UV;
	float y = clamp(uv.y, 0.0, 1.0);

	float y_h = clamp((y - horizon) / max(0.0005, 1.0 - horizon), 0.0005, 1.0);
	float raw_depth = 1.0 / y_h;
	float depth = mix(1.0, raw_depth, max(0.0, perspective_amount));
	depth = min(depth, max_distance);

	float x_dist = abs(uv.x - vanish_x);
	float edge_start = clamp(center_width, 0.0, 0.49);
	float edge_stop = max(edge_end, edge_start + 0.001);
	float edge = smoothstep(edge_start, edge_stop, x_dist);
	edge = clamp(pow(edge, edge_power) * edge_strength, 0.0, 1.0);

	float inv_depth = 1.0 / max(depth, 0.0005);
	float row = pow(1.0 - y, vertical_power);
	float row_scale = mix(1.0, inv_depth * x_scale, row);
	row_scale = max(row_scale, 0.0005);

	// Инверсное отображение создаёт реальную "трапецию" по альфе.
	float u_persp = (uv.x - vanish_x) / row_scale + vanish_x;
	float u = mix(uv.x, u_persp, edge);

	if (u < 0.0 || u > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 tex = texture(TEXTURE, vec2(u, uv.y));
		COLOR = tex * COLOR;
	}
}
