extends Node

@export_group("Trigger")
## Автоматически запускать эффект при старте уровня.
@export var auto_start: bool = true
## Задержка перед запуском эффекта (сек).
@export_range(0.0, 180.0, 0.1) var start_delay: float = 8.0
## Запускать эффект только один раз.
@export var one_shot: bool = true

@export_group("Visual")
## Общая длительность эффекта (сек).
@export_range(0.1, 30.0, 0.1) var effect_duration: float = 4.0
## Сила искажения (мягче, чем в полноценной искаженной фазе).
@export_range(0.0, 1.0, 0.05) var distortion_intensity: float = 0.62
## Сила обесцвечивания.
@export_range(0.0, 1.0, 0.05) var desaturation_amount: float = 0.9
## Тряска в шейдере.
@export_range(0.0, 0.1, 0.005) var shader_shake_power: float = 0.02
## Хроматическая аберрация.
@export_range(0.0, 0.2, 0.01) var shader_color_bleeding: float = 0.04
## Количество глитч-линий.
@export_range(0.0, 120.0, 1.0) var shader_glitch_lines: float = 40.0
## Сила виньетки.
@export_range(0.0, 2.0, 0.05) var shader_vignette_intensity: float = 0.7

@export_group("Timer Collapse")
## За сколько секунд таймер должен гарантированно упасть до нуля.
@export_range(0.1, 30.0, 0.1) var timer_collapse_duration: float = 3.8
## Степень "ускорения к нулю" (меньше 1 = быстрый обвал в начале).
@export_range(0.1, 4.0, 0.05) var timer_collapse_power: float = 0.35
## Если таймер на уровне выключен, временно включить его на это значение.
@export_range(0.0, 1200.0, 1.0) var fallback_time_if_timer_disabled: float = 60.0

@export_group("Camera Pulse")
## Явный путь к Camera2D (опционально).
@export var camera_path: NodePath
## Количество циклов "отдалиться-приблизиться".
@export_range(1, 6, 1) var pulse_count: int = 2
## Длительность половины пульса (сек).
@export_range(0.01, 2.0, 0.01) var pulse_half_duration: float = 0.22
## Сила отдаления камеры.
@export_range(0.0, 1.0, 0.01) var pulse_strength: float = 0.16

@export_group("Audio")
## Звук, который проигрывается при запуске эффекта.
@export var event_sfx: AudioStream = preload("res://music/MyHorrorHit_2.wav")
## Громкость звука эффекта (дБ).
@export_range(-80.0, 6.0, 0.1) var event_sfx_volume_db: float = 0.0
## Питч звука эффекта.
@export_range(0.1, 3.0, 0.01) var event_sfx_pitch_scale: float = 1.0

var _overlay_layer: CanvasLayer
var _overlay_rect: ColorRect
var _overlay_material: ShaderMaterial
var _sfx_player: AudioStreamPlayer
var _active: bool = false
var _triggered: bool = false
var _elapsed: float = 0.0
var _collapse_active: bool = false
var _collapse_elapsed: float = 0.0
var _collapse_start_time: float = 0.0
var _camera: Camera2D = null
var _camera_base_zoom: Vector2 = Vector2.ONE
var _camera_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Sounds"
	add_child(_sfx_player)
	_create_overlay()
	if auto_start:
		_schedule_start()

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	var duration: float = maxf(0.001, effect_duration)
	var progress := float(clamp(_elapsed / duration, 0.0, 1.0))
	var strength := _compute_strength(progress)
	_set_overlay_strength(strength)
	_update_timer_collapse(delta)
	if progress >= 1.0:
		_finish_event()

func start_event() -> void:
	_start_event()

func _schedule_start() -> void:
	if start_delay <= 0.0:
		_start_event()
		return
	get_tree().create_timer(start_delay).timeout.connect(_start_event)

func _start_event() -> void:
	if one_shot and _triggered:
		return
	_triggered = true
	_active = true
	_elapsed = 0.0
	_collapse_elapsed = 0.0
	_overlay_rect.visible = true
	_apply_overlay_static_params()
	_set_overlay_strength(0.0)
	_play_event_sfx()
	_camera = _resolve_camera()
	if _camera != null:
		_camera_base_zoom = _camera.zoom
	_play_camera_pulse()
	_prepare_timer_collapse()

func _play_event_sfx() -> void:
	if event_sfx == null:
		return
	if _sfx_player == null:
		return
	_sfx_player.stream = event_sfx
	_sfx_player.volume_db = event_sfx_volume_db
	_sfx_player.pitch_scale = event_sfx_pitch_scale
	_sfx_player.play()

func _prepare_timer_collapse() -> void:
	_collapse_active = false
	_collapse_start_time = 0.0
	if GameDirector == null:
		return
	if GameDirector.has_method("ensure_timer_running") and fallback_time_if_timer_disabled > 0.0:
		GameDirector.ensure_timer_running(fallback_time_if_timer_disabled)
	if not GameDirector.has_method("get_time_left"):
		return
	_collapse_start_time = float(GameDirector.get_time_left())
	if _collapse_start_time <= 0.0:
		return
	_collapse_active = timer_collapse_duration > 0.0

func _update_timer_collapse(delta: float) -> void:
	if not _collapse_active:
		return
	if GameDirector == null or not GameDirector.has_method("set_time_left"):
		_collapse_active = false
		return
	var collapse_duration: float = maxf(0.001, timer_collapse_duration)
	_collapse_elapsed += delta
	var t := float(clamp(_collapse_elapsed / collapse_duration, 0.0, 1.0))
	var power: float = maxf(0.1, timer_collapse_power)
	var eased := pow(t, power)
	var target_time := lerpf(_collapse_start_time, 0.0, eased)
	if t < 1.0:
		target_time = max(0.01, target_time)
	GameDirector.set_time_left(target_time)
	if t >= 1.0:
		_collapse_active = false

func _finish_event() -> void:
	_active = false
	_collapse_active = false
	if _overlay_rect:
		_overlay_rect.visible = false
	_set_overlay_strength(0.0)
	if _camera_tween and _camera_tween.is_running():
		_camera_tween.kill()
	if _camera != null and is_instance_valid(_camera):
		_camera.zoom = _camera_base_zoom
	_camera = null

func _compute_strength(progress: float) -> float:
	var fade_in_ratio := 0.12
	var fade_out_ratio := 0.22
	if progress < fade_in_ratio:
		return distortion_intensity * (progress / fade_in_ratio)
	if progress > 1.0 - fade_out_ratio:
		return distortion_intensity * ((1.0 - progress) / fade_out_ratio)
	return distortion_intensity

func _create_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 91
	add_child(_overlay_layer)
	_overlay_rect = ColorRect.new()
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.visible = false
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = preload("res://shaders/distortion_transition.gdshader")
	_overlay_rect.material = _overlay_material
	_overlay_layer.add_child(_overlay_rect)
	_apply_overlay_static_params()
	_set_overlay_strength(0.0)

func _apply_overlay_static_params() -> void:
	if _overlay_material == null:
		return
	_overlay_material.set_shader_parameter("desaturation", desaturation_amount)
	_overlay_material.set_shader_parameter("shake_power", shader_shake_power)
	_overlay_material.set_shader_parameter("color_bleeding", shader_color_bleeding)
	_overlay_material.set_shader_parameter("glitch_lines", shader_glitch_lines)
	_overlay_material.set_shader_parameter("vignette_intensity", shader_vignette_intensity)

func _set_overlay_strength(strength: float) -> void:
	if _overlay_material == null:
		return
	_overlay_material.set_shader_parameter("intensity", float(clamp(strength, 0.0, 1.0)))

func _play_camera_pulse() -> void:
	if _camera == null:
		return
	if pulse_count <= 0 or pulse_half_duration <= 0.0 or pulse_strength <= 0.0:
		return
	if _camera_tween and _camera_tween.is_running():
		_camera_tween.kill()
	var out_zoom := _camera_base_zoom * (1.0 + pulse_strength)
	_camera_tween = create_tween()
	for _i in range(pulse_count):
		_camera_tween.tween_property(_camera, "zoom", out_zoom, pulse_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_camera_tween.tween_property(_camera, "zoom", _camera_base_zoom, pulse_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _resolve_camera() -> Camera2D:
	if camera_path != NodePath(""):
		var explicit_camera := get_node_or_null(camera_path) as Camera2D
		if explicit_camera != null:
			return explicit_camera
	if get_viewport() and get_viewport().get_camera_2d():
		return get_viewport().get_camera_2d()
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_node("Camera2D"):
		return player.get_node("Camera2D") as Camera2D
	return null
