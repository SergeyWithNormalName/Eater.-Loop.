shader_type canvas_item;

// --- Настройки ---
// Насколько "глубоко" уходит пол (имитация наклона камеры)
uniform float perspective_depth : hint_range(0.1, 3.0) = 1.0;

// Угол сужения пола (трапеция)
uniform float trapezoid_width : hint_range(0.0, 1.0) = 0.5;

// Где начинается перспектива по высоте (0 = низ, 1 = верх)
uniform float perspective_start : hint_range(0.0, 1.0) = 0.55;
// Где перспектива достигает максимума (0 = низ, 1 = верх)
uniform float perspective_end : hint_range(0.0, 1.0) = 1.0;
// Насколько плавно нарастает эффект (больше = мягче)
uniform float perspective_curve : hint_range(0.5, 6.0) = 2.5;
// Общая сила перспективы (0 = плоско, 1 = полностью)
uniform float depth_strength : hint_range(0.0, 1.0) = 0.9;

// Настройки текстуры
uniform vec2 tiling = vec2(1.0, 1.0);
uniform float scroll_offset = 0.0;

void fragment() {
    // 1. Базовые UV
    vec2 uv = UV;
    float y = clamp(uv.y, 0.001, 1.0);
    float far = 1.0 - y; // 0 = низ, 1 = верх

    // 2. Вес перспективы: почти 0 в середине, плавно растет к верху
    float blend = smoothstep(perspective_start, perspective_end, far);
    blend = pow(blend, perspective_curve);

    // 3. Перспективное деление
    vec2 uv_center = uv - 0.5;
    float depth = mix(1.0, perspective_depth / y, depth_strength);

    float perspective_x = uv_center.x * depth * (1.0 - trapezoid_width);
    float perspective_y = depth;

    // 4. Смешиваем "плоское" и "перспективное" отображение
    float final_x = mix(uv_center.x + 0.5, perspective_x + 0.5, blend);
    float final_y = mix(y, perspective_y, blend);
    vec2 new_uv = vec2(final_x, final_y);

    // Применяем тайлинг и скролл
    new_uv *= tiling;
    new_uv.x += scroll_offset; // Если пол скроллится влево-вправо
    // new_uv.y += scroll_offset; // Если пол "едет" на нас (как в раннере)

    COLOR = texture(TEXTURE, new_uv);

    // Мягкое затухание у горизонта, чтобы не было "среза"
    COLOR.a *= smoothstep(0.0, 0.25, y);
}
