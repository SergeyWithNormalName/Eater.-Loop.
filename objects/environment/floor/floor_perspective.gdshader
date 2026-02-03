shader_type canvas_item;

// Сила перспективы (0 = плоско)
uniform float perspective_amount : hint_range(0.0, 0.95) = 0.8;
// Где начинается перспектива (0 = низ, 1 = верх)
uniform float flat_start : hint_range(0.0, 1.0) = 0.55;
// Где перспектива достигает максимума (0 = низ, 1 = верх)
uniform float flat_end : hint_range(0.0, 1.0) = 1.0;
// Кривизна нарастания (больше = мягче)
uniform float curve : hint_range(0.5, 6.0) = 3.0;
// Центр схода по X (0..1)
uniform float vanish_x : hint_range(0.0, 1.0) = 0.5;
// Сдвиг горизонта по Y (0 = верх спрайта)
uniform float horizon : hint_range(0.0, 1.0) = 0.0;
// Доп. масштаб по X (чтобы регулировать «трапецию»)
uniform float x_scale : hint_range(0.2, 2.0) = 1.0;

// Тайлинг и смещение текстуры
uniform vec2 tiling = vec2(5.0, 3.0);
uniform vec2 offset = vec2(0.0, 0.0);

// Плавное затухание у горизонта
uniform float fade_height : hint_range(0.0, 0.2) = 0.03;

void fragment() {
    vec2 uv = UV;

    float y = clamp(uv.y, 0.0, 1.0);
    float y_h = clamp((y - horizon) / max(0.001, 1.0 - horizon), 0.0, 1.0);

    // 0 внизу, 1 наверху
    float t = 1.0 - y_h;

    float start_v = min(flat_start, flat_end);
    float end_v = max(flat_start, flat_end);
    float blend = smoothstep(start_v, end_v, t);
    blend = pow(blend, curve);

    // Ограниченная перспектива: 1.0 внизу, растет к верху
    float depth = 1.0 / max(0.001, 1.0 - t * perspective_amount);

    float depth_x = mix(1.0, depth, blend);
    float u = (uv.x - vanish_x) * depth_x * x_scale + vanish_x;
    float v = mix(y_h, depth, blend);

    vec2 sample_uv = vec2(u, v) * tiling + offset;
    sample_uv = fract(sample_uv);

    vec4 col = texture(TEXTURE, sample_uv);

    float fade = smoothstep(0.0, fade_height, y_h);
    col.a *= fade;

    COLOR = col;
}
