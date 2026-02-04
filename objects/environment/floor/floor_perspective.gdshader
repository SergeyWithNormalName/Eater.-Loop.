shader_type canvas_item;

// Сила перспективы (0 = плоско)
uniform float perspective_amount : hint_range(0.0, 0.95) = 0.6;
// Центр схода по X (0..1)
uniform float vanish_x : hint_range(0.0, 1.0) = 0.5;
// Сдвиг горизонта по Y (0 = верх спрайта)
uniform float horizon : hint_range(0.0, 1.0) = 0.0;
// Доп. масштаб по X (чтобы регулировать «трапецию»)
uniform float x_scale : hint_range(0.2, 2.0) = 1.0;
// Сила перспективы по краям (0 = без искажения по X)
uniform float edge_strength : hint_range(0.0, 1.0) = 1.0;
// Насколько резко включается искажение по краям
uniform float edge_power : hint_range(0.5, 6.0) = 2.0;
// Старт искажения от центра (в долях ширины, 0..0.49)
uniform float center_width : hint_range(0.0, 0.49) = 0.15;
// Где искажение достигает максимума (в долях ширины, 0.01..0.5)
uniform float edge_end : hint_range(0.01, 0.5) = 0.5;

// Тайлинг и смещение текстуры
uniform vec2 tiling = vec2(5.0, 3.0);
uniform vec2 offset = vec2(0.0, 0.0);

// Конец пола по глубине (в условных единицах глубины)
uniform float max_distance : hint_range(1.0, 80.0) = 10.0;
// Плавное затухание у горизонта (0 = без затухания)
uniform float fade_length : hint_range(0.0, 20.0) = 1.0;
// Смещение уровня мипов (отрицательное = резче, положительное = мягче)
uniform float mip_bias : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV;

    float y = clamp(uv.y, 0.0, 1.0);
    float y_h = clamp((y - horizon) / max(0.0005, 1.0 - horizon), 0.0005, 1.0);

    // Ровная плоскость: 1/y_h с возможностью ослабить перспективу
    float raw_depth = 1.0 / y_h;
    float depth = mix(1.0, raw_depth, perspective_amount);
    depth = min(depth, max_distance);

    float x_dist = abs(uv.x - vanish_x);
    float edge_start = clamp(center_width, 0.0, 0.49);
    float edge_stop = max(edge_end, edge_start + 0.001);
    float edge = smoothstep(edge_start, edge_stop, x_dist);
    edge = pow(edge, edge_power) * edge_strength;

    float u_persp = (uv.x - vanish_x) * depth * x_scale + vanish_x;
    float u = mix(uv.x, u_persp, edge);
    float v = depth;

    vec2 mapped_uv = vec2(u, v) * tiling + offset;
    vec2 sample_uv = fract(mapped_uv);

    // Производные считаем по непрерывным координатам (до fract),
    // иначе мип-уровень начинает "дергаться" на границах тайлинга.
    vec2 texel_dx = dFdx(mapped_uv) / TEXTURE_PIXEL_SIZE;
    vec2 texel_dy = dFdy(mapped_uv) / TEXTURE_PIXEL_SIZE;
    float rho = max(dot(texel_dx, texel_dx), dot(texel_dy, texel_dy));
    float lod = max(0.0, 0.5 * log2(max(rho, 1e-8)));
    lod = max(lod + mip_bias, 0.0);

    vec4 col = textureLod(TEXTURE, sample_uv, lod);

    if (fade_length > 0.0) {
        float fade_start = max(0.0, max_distance - fade_length);
        float fade = 1.0 - smoothstep(fade_start, max_distance, raw_depth);
        col.a *= fade;
    }

    COLOR = col;
}
