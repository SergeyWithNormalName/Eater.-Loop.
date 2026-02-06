shader_type canvas_item;

uniform float pupil_size : hint_range(0.1, 0.5) = 0.22;
uniform vec2 eye_offset = vec2(0.0);
uniform float horror_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float vein_speed : hint_range(0.0, 5.0) = 1.8;
uniform float eye_width : hint_range(0.7, 1.8) = 1.22;
uniform float eye_height : hint_range(0.5, 1.5) = 0.86;
uniform float upper_lid_offset : hint_range(-0.4, 0.5) = 0.28;
uniform float lower_lid_offset : hint_range(-0.6, 0.3) = -0.25;
uniform float lid_curve : hint_range(0.0, 0.5) = 0.18;
uniform float lid_softness : hint_range(0.005, 0.12) = 0.035;
uniform float corner_narrowing : hint_range(0.0, 0.4) = 0.0;
uniform bool writhing_lines_enabled = true;
uniform float writhing_lines_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float writhing_lines_speed : hint_range(0.0, 6.0) = 2.4;
uniform float writhing_lines_thickness : hint_range(0.05, 0.8) = 0.34;
uniform float writhing_lines_distortion : hint_range(0.0, 1.0) = 0.28;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise(p) * amplitude;
		p = p * 2.02 + vec2(17.31, 9.47);
		amplitude *= 0.5;
	}
	return value;
}

float vein_field(vec2 p, float t) {
	float polar = fbm(vec2(atan(p.y, p.x) * 5.5 + t * 0.9, length(p) * 11.0 - t * 1.1));
	float flow = fbm(p * 7.5 + vec2(t * 0.7, -t * 0.45));
	float micro = fbm(p * 16.0 + vec2(-t * 1.3, t * 0.8));
	return clamp(polar * 0.45 + flow * 0.45 + micro * 0.35, 0.0, 1.0);
}

void fragment() {
	vec2 eye_uv = (UV - 0.5) * 2.0;
	vec2 ellipse_uv = vec2(eye_uv.x * eye_width, eye_uv.y * eye_height);
	float ellipse_r = length(ellipse_uv);

	float eye_shape = 1.0 - smoothstep(0.94, 1.03, ellipse_r);
	float upper_lid_y = upper_lid_offset - eye_uv.x * eye_uv.x * lid_curve - abs(eye_uv.x) * corner_narrowing;
	float lower_lid_y = lower_lid_offset + eye_uv.x * eye_uv.x * (lid_curve * 0.66) + abs(eye_uv.x) * (corner_narrowing * 0.5);
	float upper_mask = 1.0 - smoothstep(upper_lid_y - lid_softness, upper_lid_y + lid_softness, eye_uv.y);
	float lower_mask = smoothstep(lower_lid_y - lid_softness, lower_lid_y + lid_softness, eye_uv.y);
	float eye_mask = eye_shape * upper_mask * lower_mask;

	vec2 gaze = eye_offset * 2.0;
	float gaze_len = length(gaze);
	if (gaze_len > 0.32) {
		gaze = gaze / gaze_len * 0.32;
	}

	vec2 iris_uv = eye_uv - gaze;
	float iris_dist = length(iris_uv);
	float iris_radius = 0.33;
	float iris_mask = 1.0 - smoothstep(iris_radius, iris_radius + 0.02, iris_dist);

	vec3 sclera = vec3(0.88, 0.84, 0.77);
	float sclera_grad = smoothstep(0.12, 1.0, ellipse_r);
	sclera = mix(sclera, vec3(0.74, 0.67, 0.57), sclera_grad * 0.9);
	float sclera_noise = fbm(eye_uv * 5.8 + vec2(0.0, TIME * 0.08));
	sclera += (sclera_noise - 0.5) * 0.07 * horror_intensity;

	float t = TIME * vein_speed;
	float veins = vein_field(eye_uv, t);
	float moving_caps = smoothstep(0.80, 0.94, fbm(eye_uv * 18.0 + vec2(t * 1.2, -t * 0.8)) + veins * 0.45);
	float vein_mask = smoothstep(iris_radius + 0.07, 0.95, ellipse_r);
	float vein_strength = clamp((veins * 0.75 + moving_caps * 0.55) * vein_mask * horror_intensity, 0.0, 1.0);
	sclera = mix(sclera, vec3(0.46, 0.02, 0.02), vein_strength * 0.65);

	float clots = smoothstep(0.78, 0.94, fbm(eye_uv * 11.0 + vec2(-TIME * 0.07, TIME * 0.05)));
	clots *= smoothstep(0.52, 0.95, ellipse_r);
	sclera = mix(sclera, vec3(0.33, 0.06, 0.03), clots * 0.45 * horror_intensity);

	if (writhing_lines_enabled) {
		float wr_t = TIME * writhing_lines_speed;
		vec2 wriggle = vec2(
			sin(eye_uv.y * 22.0 + wr_t * 2.1),
			cos(eye_uv.x * 19.0 - wr_t * 1.9)
		) * writhing_lines_distortion;
		vec2 vessel_uv = eye_uv * 9.0 + wriggle + vec2(wr_t * 0.9, -wr_t * 0.7);
		float vessel_noise = fbm(vessel_uv + vec2(fbm(vessel_uv * 0.5), fbm(vessel_uv * 0.6)) * 2.0);
		float vessel_wave = abs(sin(vessel_uv.x * 3.6 + vessel_uv.y * 2.7 + vessel_noise * 12.0));
		float vessel_lines = smoothstep(1.0 - writhing_lines_thickness, 1.0, vessel_wave);
		float vessel_branch = smoothstep(0.55, 0.88, fbm(vessel_uv * 0.85 + vec2(-wr_t, wr_t * 0.6)));
		float vessel_pulse = 0.6 + 0.4 * sin(wr_t * 4.2 + fbm(eye_uv * 8.0) * 6.0);
		float wr_mask = smoothstep(iris_radius + 0.05, 0.97, ellipse_r) * upper_mask * lower_mask;
		float wr_strength = clamp(vessel_lines * vessel_branch * wr_mask * writhing_lines_intensity * vessel_pulse, 0.0, 1.0);
		sclera = mix(sclera, vec3(0.55, 0.01, 0.01), wr_strength * 0.85);
	}

	float theta = atan(iris_uv.y, iris_uv.x);
	float radial = 1.0 - clamp(iris_dist / iris_radius, 0.0, 1.0);
	float iris_noise = fbm(vec2(theta * 8.5, iris_dist * 14.0 - TIME * 0.5));
	float fibers = abs(sin(theta * 65.0 + iris_noise * 8.0 + TIME * 0.25));
	float crypts = fbm(vec2(theta * 3.0 + TIME * 0.04, iris_dist * 22.0));

	vec3 iris_color = mix(vec3(0.08, 0.05, 0.03), vec3(0.35, 0.20, 0.08), pow(radial, 0.72));
	iris_color += vec3(0.12, 0.08, 0.02) * fibers * pow(radial, 1.4);
	iris_color -= vec3(0.09, 0.05, 0.02) * smoothstep(0.45, 0.9, crypts) * (1.0 - radial * 0.4);

	float limbal = smoothstep(iris_radius * 0.68, iris_radius, iris_dist);
	iris_color = mix(iris_color, vec3(0.02, 0.01, 0.0), limbal * 0.9);

	float pulse = sin(TIME * 2.6) * 0.5 + 0.5;
	float pupil_radius = pupil_size * (0.9 + pulse * 0.18);
	vec2 pupil_jitter = vec2(sin(TIME * 37.0), cos(TIME * 31.0)) * 0.004;
	float pupil_dist = length(iris_uv + pupil_jitter);
	float pupil_mask = 1.0 - smoothstep(pupil_radius, pupil_radius + 0.015, pupil_dist);

	vec3 color = sclera;
	color = mix(color, iris_color, iris_mask);
	color = mix(color, vec3(0.0), pupil_mask);

	float top_shadow = smoothstep(-0.04, 0.35, eye_uv.y + 0.10 + eye_uv.x * eye_uv.x * 0.2);
	color *= 1.0 - top_shadow * 0.24 * horror_intensity;

	float corner_grime = smoothstep(0.70, 1.0, abs(eye_uv.x)) * smoothstep(-0.22, 0.16, eye_uv.y);
	color = mix(color, vec3(0.30, 0.09, 0.06), corner_grime * 0.5);

	float edge_dark = smoothstep(0.55, 0.98, ellipse_r);
	color *= 1.0 - edge_dark * 0.32;

	vec2 spec_uv = iris_uv;
	float spec_a = exp(-dot(spec_uv - vec2(-0.11, -0.14), spec_uv - vec2(-0.11, -0.14)) * 180.0);
	float spec_b = exp(-dot(spec_uv - vec2(-0.05, -0.18), spec_uv - vec2(-0.05, -0.18)) * 360.0);
	float spec_c = exp(-dot(spec_uv - vec2(0.14, 0.05), spec_uv - vec2(0.14, 0.05)) * 115.0) * 0.55;
	color += vec3(1.0, 0.98, 0.95) * (spec_a * 0.42 + spec_b * 0.32 + spec_c * 0.17);

	float tear_line = exp(-pow(eye_uv.y - (lower_lid_y - 0.01), 2.0) * 550.0) * (1.0 - smoothstep(0.45, 1.0, abs(eye_uv.x)));
	color += vec3(0.10, 0.08, 0.07) * tear_line * 0.8;

	color = clamp(color, vec3(0.0), vec3(1.0));
	COLOR = vec4(color, clamp(eye_mask, 0.0, 1.0));
}
