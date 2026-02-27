shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// Основной параметр силы боли (от 0.0 до 1.0). Им нужно управлять из скрипта.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// Настройки пульсации (бешеное сердцебиение при шоке)
uniform float shock_pulse_speed : hint_range(1.0, 30.0) = 12.0;

// Цвет помутнения/крови по краям экрана
uniform vec3 pain_color : source_color = vec3(0.7, 0.0, 0.0);

void fragment() {
    vec2 uv = SCREEN_UV;

    // Резкая, рваная пульсация, имитирующая удары сердца или спазмы боли
    float pulse = pow(abs(sin(TIME * shock_pulse_speed)), 6.0);
    // Добавляем легкий хаос в ритм, чтобы он не казался искусственным
    float chaotic_pulse = pulse * (0.8 + 0.2 * sin(TIME * 33.0));

    // Итоговая сила эффекта в данный кадр (сочетает общую интенсивность и пульс)
    float current_intensity = intensity * (0.3 + 0.7 * chaotic_pulse);

    // Искажение пространства (эффект контузии / резкого зума при ударе)
    vec2 center = vec2(0.5, 0.5);
    vec2 dir = uv - center;
    vec2 distorted_uv = uv - dir * current_intensity * 0.06;

    // Хроматическая аберрация (раздвоение цветов как при сильном ударе по голове)
    float ab_shift = current_intensity * 0.05;
    float r = texture(screen_texture, distorted_uv + vec2(ab_shift, 0.0)).r;
    float g = texture(screen_texture, distorted_uv).g;
    float b = texture(screen_texture, distorted_uv - vec2(ab_shift, 0.0)).b;
    vec3 color = vec3(r, g, b);

    // Выжигающий контраст (как в сценах с Трагером или на кресте)
    vec3 high_contrast = smoothstep(vec3(0.15), vec3(0.85), color);
    color = mix(color, high_contrast, current_intensity * 1.2);

    // Резкое повышение насыщенности (кислотные, бьющие по глазам цвета)
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 grayscale = vec3(lum);
    color = mix(color, color + (color - grayscale) * 3.0, current_intensity);

    // Кровавая виньетка (затемнение и покраснение краев экрана)
    // Зависит от общего параметра intensity, чтобы края оставались красными даже между ударами пульса
    float dist = distance(uv, vec2(0.5));
    float vignette = smoothstep(0.35, 0.8, dist) * intensity; 
    color = mix(color, color * pain_color * 1.5, vignette);

    // Общий болезненный желтовато-красный оттенок на весь экран при пике боли
    vec3 global_tint = vec3(1.2, 0.8, 0.7);
    color = mix(color, color * global_tint, current_intensity * 0.5);

    // Ограничиваем цвета, чтобы не было артефактов
    COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
