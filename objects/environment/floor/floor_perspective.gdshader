shader_type canvas_item;

// Сила перспективы (0 = плоско)
uniform float perspective_amount : hint_range(0.0, 0.95) = 0.6;
// Центр схода по X (0..1)
uniform float vanish_x : hint_range(0.0, 1.0) = 0.5;
// Сдвиг горизонта по Y (0 = верх спрайта)
uniform float horizon : hint_range(0.0, 1.0) = 0.0;
// Доп. масштаб по X (чтобы регулировать «трапецию»)
uniform float x_scale : hint_range(0.2, 2.0) = 1.0;

// Тайлинг и смещение текстуры
uniform vec2 tiling = vec2(5.0, 3.0);
uniform vec2 offset = vec2(0.0, 0.0);

// Конец пола по глубине (в условных единицах глубины)
uniform float max_distance : hint_range(1.0, 80.0) = 8.0;

void fragment() {
    vec2 uv = UV;

    float y = clamp(uv.y, 0.0, 1.0);
    float y_h = clamp((y - horizon) / max(0.001, 1.0 - horizon), 0.0, 1.0);

    // 1.0 внизу, растет к горизонту
    float inv = 1.0 / max(0.001, y_h);
    float depth_unclamped = mix(1.0, inv, perspective_amount);
    if (depth_unclamped > max_distance) {
        COLOR = vec4(0.0);
        return;
    }

    float depth = depth_unclamped;
    float u = (uv.x - vanish_x) * depth * x_scale + vanish_x;
    float v = depth;

    if (v > max_distance) {
        COLOR = vec4(0.0);
        return;
    }
    vec2 sample_uv_raw = vec2(u, v) * tiling + offset;
    vec2 sample_uv = fract(sample_uv_raw);

    vec4 col = texture(TEXTURE, sample_uv);

    COLOR = col;
}
