@tool
extends Node2D

## Показывать глаз только после истечения таймера цикла (в фазе DISTORTED).
@export var show_only_after_cycle_distortion: bool = false

@export_group("Tracking")
## Имя группы, в которой ищется игрок.
@export var player_group: StringName = &"player"
## Максимальное смещение взгляда (зрачка) от центра глаза.
@export var max_eye_offset: float = 0.12
## Скорость, с которой глаз доводит взгляд до цели.
@export var tracking_speed: float = 10.0
## Амплитуда постоянной мелкой дрожи глаза.
@export var idle_shake_strength: float = 0.01
## Сила случайных микрорывков (саккад) взгляда.
@export var saccade_strength: float = 0.03
## Минимальный интервал между саккадами.
@export var saccade_interval_min: float = 0.08
## Максимальный интервал между саккадами.
@export var saccade_interval_max: float = 0.35

@export_group("Pupil")
## Базовый размер зрачка, когда игрок далеко.
@export var pupil_size_far: float = 0.18
## Размер зрачка, когда игрок близко.
@export var pupil_size_near: float = 0.30
## Дистанция, на которой зрачок полностью реагирует на близость игрока.
@export var pupil_react_distance: float = 900.0
## Частота пульсации размера зрачка.
@export var pupil_pulse_speed: float = 2.5
## Амплитуда пульсации размера зрачка.
@export var pupil_pulse_amount: float = 0.015

@export_group("Shader")
## Общая интенсивность хоррор-деталей шейдера.
@export var horror_intensity: float = 1.2
## Скорость анимации вен и капилляров.
@export var vein_speed: float = 1.8

@export_group("Writhing Vessels")
## Включить дополнительный слой извивающихся сосудов.
@export var writhing_lines_enabled: bool = true
## Интенсивность слоя извивающихся сосудов.
@export var writhing_lines_intensity: float = 1.0
## Скорость движения и извивания сосудов.
@export var writhing_lines_speed: float = 2.4
## Толщина линий сосудов.
@export var writhing_lines_thickness: float = 0.34
## Сила деформации и "скручивания" линий сосудов.
@export var writhing_lines_distortion: float = 0.28

@export_group("Eye Shape")
## Растяжение глаза по ширине (форма яблока), зрачок не масштабируется отдельно.
@export var eye_width: float = 1.22
## Растяжение глаза по высоте (форма яблока), зрачок не масштабируется отдельно.
@export var eye_height: float = 0.86
## Положение верхнего века (выше/ниже).
@export var upper_lid_offset: float = 0.28
## Положение нижнего века (выше/ниже).
@export var lower_lid_offset: float = -0.25
## Кривизна век (насколько сильный изгиб дуги).
@export var lid_curve: float = 0.18
## Мягкость края век (жёсткий или плавный край).
@export var lid_softness: float = 0.035
## Дополнительное сужение глаза к уголкам.
@export var corner_narrowing: float = 0.0

@onready var eye_sprite: Sprite2D = $EyeSprite

var _player: Node2D
var _material: ShaderMaterial
var _eye_offset: Vector2 = Vector2.ZERO
var _saccade_timer: float = 0.0
var _saccade_offset: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_material = eye_sprite.material as ShaderMaterial
	if _material != null:
		_apply_shader_static_params()
	_saccade_timer = _rng.randf_range(maxf(0.02, saccade_interval_min), maxf(saccade_interval_min + 0.01, saccade_interval_max))
	_resolve_player()

func _process(delta: float) -> void:
	_apply_visibility_rule()
	if not visible:
		return

	_resolve_player()

	_update_saccade(delta)

	var target_offset := Vector2.ZERO
	if _player != null:
		var to_player := _player.global_position - global_position
		if to_player.length_squared() > 0.0001:
			target_offset = to_player.normalized() * max_eye_offset

	var t := Time.get_ticks_msec() * 0.001
	var idle_shake := Vector2(sin(t * 2.7), cos(t * 3.2)) * idle_shake_strength
	target_offset = (target_offset + idle_shake + _saccade_offset).limit_length(max_eye_offset)

	var weight := clampf(delta * tracking_speed, 0.0, 1.0)
	_eye_offset = _eye_offset.lerp(target_offset, weight)

	if _material != null:
		# Keep editor preview in sync when export vars change.
		_apply_shader_static_params()
		_material.set_shader_parameter("eye_offset", _eye_offset)
		_material.set_shader_parameter("pupil_size", _compute_dynamic_pupil_size(t))

func _apply_shader_static_params() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("horror_intensity", horror_intensity)
	_material.set_shader_parameter("vein_speed", vein_speed)
	_material.set_shader_parameter("writhing_lines_enabled", writhing_lines_enabled)
	_material.set_shader_parameter("writhing_lines_intensity", writhing_lines_intensity)
	_material.set_shader_parameter("writhing_lines_speed", writhing_lines_speed)
	_material.set_shader_parameter("writhing_lines_thickness", writhing_lines_thickness)
	_material.set_shader_parameter("writhing_lines_distortion", writhing_lines_distortion)
	_material.set_shader_parameter("eye_width", eye_width)
	_material.set_shader_parameter("eye_height", eye_height)
	_material.set_shader_parameter("upper_lid_offset", upper_lid_offset)
	_material.set_shader_parameter("lower_lid_offset", lower_lid_offset)
	_material.set_shader_parameter("lid_curve", lid_curve)
	_material.set_shader_parameter("lid_softness", lid_softness)
	_material.set_shader_parameter("corner_narrowing", corner_narrowing)

func _apply_visibility_rule() -> void:
	var should_show := true
	if show_only_after_cycle_distortion:
		should_show = _is_distorted_phase_active()
	visible = should_show

func _is_distorted_phase_active() -> bool:
	if Engine.is_editor_hint():
		return true
	if GameState == null:
		return false
	return int(GameState.phase) == int(GameState.Phase.DISTORTED)

func _update_saccade(delta: float) -> void:
	_saccade_timer -= delta
	if _saccade_timer <= 0.0:
		_saccade_timer = _rng.randf_range(maxf(0.02, saccade_interval_min), maxf(saccade_interval_min + 0.01, saccade_interval_max))
		var angle := _rng.randf() * TAU
		var magnitude := _rng.randf_range(0.0, saccade_strength)
		_saccade_offset = Vector2.RIGHT.rotated(angle) * magnitude
	_saccade_offset = _saccade_offset.lerp(Vector2.ZERO, clampf(delta * 24.0, 0.0, 1.0))

func _compute_dynamic_pupil_size(t: float) -> float:
	var proximity := 0.0
	if _player != null:
		var dist := global_position.distance_to(_player.global_position)
		proximity = 1.0 - clampf(dist / maxf(1.0, pupil_react_distance), 0.0, 1.0)
	var target := lerpf(pupil_size_far, pupil_size_near, proximity)
	target += sin(t * pupil_pulse_speed) * pupil_pulse_amount
	return clampf(target, 0.1, 0.5)

func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group(player_group) as Node2D
