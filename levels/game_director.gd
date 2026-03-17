extends Node

signal distortion_started

## Время по умолчанию, если на уровне не задано.
@export var default_time: float = 15.0
## Длительность плавного появления постоянного искажения (сек).
@export_range(0.5, 10.0, 0.1) var distortion_ramp_duration: float = 2.0
## Сила сплющивания камеры для постоянного искажения.
@export_range(0.0, 0.2, 0.005) var distortion_squash_amount: float = 0.08
## Длительность переходного эффекта сразу после искажения (сек).
@export_range(1.0, 6.0, 0.1) var distortion_transition_duration: float = 4.0
## Сила переходного эффекта сразу после искажения.
@export_range(0.0, 1.0, 0.05) var distortion_transition_intensity: float = 1.0
## Сила сплющивания камеры в переходном эффекте.
@export_range(0.0, 0.2, 0.005) var distortion_transition_squash_amount: float = 0.25

@export_group("Stalker Spawn")
## Сцена сталкера для спавна по окончанию таймера.
@export var stalker_scene: PackedScene = preload("res://enemies/stalker/enemy_stalker.tscn")

@export_group("Damage Flash")
## Длительность резкого эффекта от урона (сек).
@export_range(0.01, 1.0, 0.01) var damage_flash_duration: float = 0.15
## Интенсивность резкого эффекта от урона.
@export_range(0.0, 1.0, 0.05) var damage_flash_intensity: float = 1.0
## Сила обесцвечивания в резком эффекте от урона.
@export_range(0.0, 1.0, 0.05) var damage_flash_desaturation: float = 0.85
## Сила тряски в резком эффекте от урона.
@export_range(0.0, 0.12, 0.005) var damage_flash_shake_power: float = 0.06
## Сила хроматической аберрации в резком эффекте от урона.
@export_range(0.0, 0.2, 0.01) var damage_flash_color_bleeding: float = 0.09
## Количество полос глитча в резком эффекте от урона.
@export_range(0.0, 140.0, 1.0) var damage_flash_glitch_lines: float = 95.0
## Сила виньетки в резком эффекте от урона.
@export_range(0.0, 2.0, 0.05) var damage_flash_vignette_intensity: float = 1.35
## Насколько резко отдаляется камера при ударе.
@export_range(0.0, 0.6, 0.01) var damage_flash_camera_zoom_punch: float = 0.14
## Максимальный случайный сдвиг камеры при ударе (px).
@export_range(0.0, 60.0, 0.5) var damage_flash_camera_offset_jitter: float = 12.0
## Поворот камеры при ударе (градусы).
@export_range(0.0, 12.0, 0.1) var damage_flash_camera_tilt_deg: float = 1.8

@export_group("LightOnly Jump FX")
## Включить экранный эффект скачка для врагов light_only.
@export var light_only_jump_effect_enabled: bool = true
## Пиковая интенсивность эффекта при скачке.
@export_range(0.0, 1.0, 0.05) var light_only_jump_peak_intensity: float = 1.0
## Длительность резкого появления эффекта (сек).
@export_range(0.01, 0.3, 0.01) var light_only_jump_attack_duration: float = 0.05
## Длительность плавного затухания эффекта (сек).
@export_range(0.05, 1.0, 0.01) var light_only_jump_release_duration: float = 0.2
## Скорость анимации шума.
@export_range(0.0, 80.0, 0.5) var light_only_jump_noise_speed: float = 30.0
## Сила горизонтальных разрывов строк.
@export_range(0.0, 0.4, 0.005) var light_only_jump_glitch_amount: float = 0.08

@export_group("Death Screen")
## Длительность затемнения до экрана смерти (сек).
@export_range(0.05, 3.0, 0.05) var death_fade_duration: float = 0.55
## Наклон камеры при смерти (градусы).
@export_range(0.0, 20.0, 0.1) var death_camera_tilt_deg: float = 5.0
## Множитель зума камеры при смерти.
@export_range(1.0, 2.5, 0.01) var death_camera_zoom_mult: float = 1.08
## Заголовок после завершения особой цепочки смертей.
@export var death_title_text: String = "Умер"
## Текст кнопки повтора.
@export var death_retry_text: String = "Попробовать ещё раз"

var _timer: Timer
var _overlay_layer: CanvasLayer
var _distortion_rect: ColorRect
var _distortion_material: ShaderMaterial
var _transition_rect: ColorRect
var _transition_material: ShaderMaterial
var _damage_rect: ColorRect
var _damage_material: ShaderMaterial
var _light_only_jump_rect: ColorRect
var _light_only_jump_material: ShaderMaterial
var _light_only_jump_tween: Tween = null
var current_max_time: float = 1.0
var _current_cycle_number: int = 0
var _current_timer_duration: float = 0.0
var _distortion_active: bool = false
var _distortion_progress: float = 0.0
var _transition_active: bool = false
var _transition_progress: float = 0.0
var _flash_active: bool = false
var _damage_flash_active: bool = false
var _light_only_jump_active: bool = false
var _minigame_active: bool = false
var _minigame_blocks_distortion: bool = false
var _pending_distortion_activation: bool = false
var _in_game_scene: bool = false
var _stalker_spawned: bool = false
var _death_layer: CanvasLayer
var _death_fade_rect: ColorRect
var _death_root: Control
var _death_glitch_background: Control
var _death_title_label: Label
var _death_retry_button: Button
var _death_sequence_active: bool = false
var _death_camera: Camera2D = null
var _death_camera_base_rotation: float = 0.0
var _death_camera_base_zoom: Vector2 = Vector2.ONE
var _death_camera_base_offset: Vector2 = Vector2.ZERO
var _input_kind: int = 0
var _death_focus_style_hidden: StyleBoxEmpty
var _death_title_glitch_material: ShaderMaterial = null
var _death_title_readable_glitch_material: ShaderMaterial = null
var _death_title_sequence_index: int = 0

const STALKER_SPAWN_GROUP := "stalker_spawn"
const INPUT_KIND_KEYBOARD := 0
const INPUT_KIND_GAMEPAD := 1
const INPUT_KIND_UNKNOWN := -1
const JOYPAD_MOTION_DEADZONE := 0.45
const CycleLevelBase = preload("res://levels/cycles/level.gd")
const DistortionPhaseControllerScript = preload("res://levels/game_director/distortion_phase_controller.gd")
const ScreenFxOverlayControllerScript = preload("res://levels/game_director/screen_fx_overlay_controller.gd")
const DeathSequenceControllerScript = preload("res://levels/game_director/death_sequence_controller.gd")
const DEATH_TITLE_GLITCH_SHADER: Shader = preload("res://shaders/death_text_glitch.gdshader")
const LIGHT_ONLY_JUMP_SHADER: Shader = preload("res://shaders/light_only_jump_overlay.gdshader")
const DEATH_TITLE_PENANCE_LINE := "Никогда не заслужу прощения."
const DEATH_TITLE_PENANCE_TEXT := "Никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения, никогда, никогда, никогда, никогда не заслужу прощения"
const DEATH_TITLE_SEQUENCE: Array[String] = [
	"Ошибся",
	"Напортачил",
	"Оплошал",
	"Накосячил",
	"Провинился",
	"Облажался",
	"Согрешил",
	DEATH_TITLE_PENANCE_TEXT,
]
const DEATH_GLITCH_BACKGROUND_LAYOUT := [
	{"anchor": Vector2(0.06, 0.08), "offset": Vector2(-280.0, -120.0), "width": 860.0, "font_size": 70, "rotation": -0.22, "scale": Vector2(1.26, 1.26), "alpha": 0.2, "strength": 0.82},
	{"anchor": Vector2(0.48, 0.03), "offset": Vector2(-140.0, -160.0), "width": 940.0, "font_size": 78, "rotation": 0.12, "scale": Vector2(1.38, 1.38), "alpha": 0.15, "strength": 0.72},
	{"anchor": Vector2(0.88, 0.1), "offset": Vector2(-110.0, -90.0), "width": 760.0, "font_size": 62, "rotation": 0.2, "scale": Vector2(1.14, 1.14), "alpha": 0.22, "strength": 0.88},
	{"anchor": Vector2(0.0, 0.48), "offset": Vector2(-320.0, -60.0), "width": 980.0, "font_size": 74, "rotation": -0.08, "scale": Vector2(1.32, 1.32), "alpha": 0.17, "strength": 0.78},
	{"anchor": Vector2(0.8, 0.44), "offset": Vector2(60.0, -20.0), "width": 900.0, "font_size": 68, "rotation": -0.18, "scale": Vector2(1.18, 1.18), "alpha": 0.18, "strength": 0.8},
	{"anchor": Vector2(0.12, 0.78), "offset": Vector2(-200.0, 10.0), "width": 840.0, "font_size": 64, "rotation": 0.18, "scale": Vector2(1.22, 1.22), "alpha": 0.18, "strength": 0.86},
	{"anchor": Vector2(0.54, 0.82), "offset": Vector2(-60.0, 20.0), "width": 980.0, "font_size": 76, "rotation": -0.12, "scale": Vector2(1.42, 1.42), "alpha": 0.14, "strength": 0.74},
	{"anchor": Vector2(0.9, 0.92), "offset": Vector2(-40.0, 60.0), "width": 740.0, "font_size": 60, "rotation": 0.26, "scale": Vector2(1.1, 1.1), "alpha": 0.2, "strength": 0.9},
]

var _distortion_phase_controller = DistortionPhaseControllerScript.new()
var _screen_fx_controller = ScreenFxOverlayControllerScript.new()
var _death_sequence_controller = DeathSequenceControllerScript.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_timer.timeout.connect(_on_distortion_timeout)
	add_child(_timer)
	_create_distortion_overlay()
	_create_death_overlay()
	_connect_minigame_controller()
	if get_tree():
		get_tree().scene_changed.connect(_on_scene_changed)
	_update_for_scene(get_tree().current_scene)

func _input(event: InputEvent) -> void:
	var next_input_kind := _resolve_input_kind(event)
	if next_input_kind == INPUT_KIND_UNKNOWN:
		return
	if next_input_kind == _input_kind:
		return
	_input_kind = next_input_kind
	if _death_sequence_active:
		_apply_death_input_mode()

func _process(delta: float) -> void:
	_screen_fx_controller.process_frame(self, delta)

func start_normal_phase(timer_duration: float = -1.0) -> void:
	_distortion_phase_controller.start_normal_phase(self, timer_duration)

func reduce_time(amount: float, damage_flash: bool = false) -> void:
	_distortion_phase_controller.reduce_time(self, amount, damage_flash)

func trigger_damage_flash() -> void:
	_distortion_phase_controller.trigger_damage_flash(self)

func _on_distortion_timeout() -> void:
	_distortion_phase_controller.on_distortion_timeout(self)

func _activate_distortion_phase() -> void:
	_distortion_phase_controller.activate_distortion_phase(self)

func _should_defer_distortion_activation() -> bool:
	return _distortion_phase_controller.should_defer_distortion_activation(self)

func trigger_distortion_now() -> void:
	if _death_sequence_active:
		return
	if not _in_game_scene:
		return
	_on_distortion_timeout()

func get_time_ratio() -> float:
	return _distortion_phase_controller.get_time_ratio(self)

func get_time_left() -> float:
	return _distortion_phase_controller.get_time_left(self)

func is_timer_running() -> bool:
	return _distortion_phase_controller.is_timer_running(self)

func ensure_timer_running(fallback_time: float) -> void:
	_distortion_phase_controller.ensure_timer_running(self, fallback_time)

func set_time_left(new_time: float) -> void:
	_distortion_phase_controller.set_time_left(self, new_time)

func _create_distortion_overlay() -> void:
	_screen_fx_controller.create_distortion_overlay(self)

func _flash_red() -> void:
	_screen_fx_controller.flash_red(self)

func _flash_damage() -> void:
	_screen_fx_controller.flash_damage(self)

func _on_scene_changed(scene: Node = null) -> void:
	if scene == null:
		scene = get_tree().current_scene
	_update_for_scene(scene)

func _update_for_scene(scene: Node) -> void:
	_reset_death_screen_state()
	var path := scene.scene_file_path if scene else ""
	_in_game_scene = path.find("/levels/cycles/") != -1
	_minigame_active = false
	_minigame_blocks_distortion = false
	_pending_distortion_activation = false
	_set_mouse_visibility(_in_game_scene)
	if _in_game_scene:
		_apply_level_settings(scene)
		return
	_timer.stop()
	_distortion_active = false
	_distortion_progress = 0.0
	_transition_active = false
	_transition_progress = 0.0
	_flash_active = false
	_stop_light_only_jump_effect()
	_stalker_spawned = false
	_hide_distortion_overlays()
	if CycleState != null:
		CycleState.set_phase(CycleState.Phase.NORMAL)

func _apply_level_settings(scene: Node) -> void:
	_distortion_phase_controller.apply_level_settings(self, scene)

func _resolve_cycle_number(scene: Node) -> int:
	return _distortion_phase_controller.resolve_cycle_number(self, scene)

func _resolve_timer_duration(scene: Node) -> float:
	return _distortion_phase_controller.resolve_timer_duration(self, scene)

func _set_mouse_visibility(in_game: bool) -> void:
	if CursorManager:
		CursorManager.set_in_game(in_game)

func _create_death_overlay() -> void:
	_death_sequence_controller.create_death_overlay(self)

func trigger_death_screen() -> void:
	_death_sequence_controller.trigger_death_screen(self)

func _handle_custom_scene_death() -> bool:
	return _death_sequence_controller.handle_custom_scene_death(self)

func _on_death_fade_completed() -> void:
	_death_sequence_controller.on_death_fade_completed(self)

func _on_death_retry_pressed() -> void:
	await _death_sequence_controller.on_death_retry_pressed(self)

func _reset_death_screen_state() -> void:
	_death_sequence_controller.reset_death_screen_state(self)

func _restore_death_camera() -> void:
	_death_sequence_controller.restore_death_camera(self)

func _set_distortion_intensity(value: float) -> void:
	if _distortion_material == null:
		return
	_distortion_material.set_shader_parameter("intensity", value)

func _set_distortion_squash(value: float) -> void:
	if _distortion_material == null:
		return
	_distortion_material.set_shader_parameter("squash_amount", value)

func _set_transition_intensity(value: float) -> void:
	if _transition_material == null:
		return
	_transition_material.set_shader_parameter("intensity", value)

func _set_transition_squash(value: float) -> void:
	if _transition_material == null:
		return
	_transition_material.set_shader_parameter("squash_amount", value)

func _set_damage_intensity(value: float) -> void:
	if _damage_material == null:
		return
	_damage_material.set_shader_parameter("intensity", value)

func _set_light_only_jump_intensity(value: float) -> void:
	if _light_only_jump_material == null:
		return
	_light_only_jump_material.set_shader_parameter("intensity", float(clamp(value, 0.0, 1.0)))

func _get_light_only_jump_intensity() -> float:
	if _light_only_jump_material == null:
		return 0.0
	var value: Variant = _light_only_jump_material.get_shader_parameter("intensity")
	if value == null:
		return 0.0
	return clampf(float(value), 0.0, 1.0)

func _configure_light_only_jump_material() -> void:
	_screen_fx_controller.configure_light_only_jump_material(self)

func trigger_light_only_jump_effect(peak_intensity: float = -1.0) -> void:
	_screen_fx_controller.trigger_light_only_jump_effect(self, peak_intensity)

func _on_light_only_jump_effect_finished() -> void:
	_screen_fx_controller.on_light_only_jump_effect_finished(self)

func _stop_light_only_jump_effect() -> void:
	_screen_fx_controller.stop_light_only_jump_effect(self)

func _configure_damage_material() -> void:
	_screen_fx_controller.configure_damage_material(self)

func _apply_next_death_title() -> void:
	_death_sequence_controller.apply_next_death_title(self)

func _apply_death_title(text: String, glitchy: bool) -> void:
	_death_sequence_controller.apply_death_title(self, text, glitchy)

func _update_death_title_layout(glitchy: bool = false) -> void:
	_death_sequence_controller.update_death_title_layout(self, glitchy)

func _get_readable_death_glitch_text(text: String) -> String:
	return _death_sequence_controller.get_readable_death_glitch_text(self, text)

func _build_death_glitch_material(glitch_strength: float, line_jitter: float, chroma_shift: float, scanline_strength: float, flicker_speed: float, tint: Color) -> ShaderMaterial:
	return _death_sequence_controller.build_death_glitch_material(self, glitch_strength, line_jitter, chroma_shift, scanline_strength, flicker_speed, tint)

func _show_death_glitch_background(text: String) -> void:
	_death_sequence_controller.show_death_glitch_background(self, text)

func _build_death_glitch_background_text(text: String) -> String:
	return _death_sequence_controller.build_death_glitch_background_text(self, text)

func _apply_damage_camera_punch() -> void:
	_screen_fx_controller.apply_damage_camera_punch(self)

func _resolve_primary_camera() -> Camera2D:
	return _screen_fx_controller.resolve_primary_camera(self)

func _apply_death_input_mode() -> void:
	_death_sequence_controller.apply_death_input_mode(self)

func _release_death_cursor_request() -> void:
	_death_sequence_controller.release_death_cursor_request(self)

func _resolve_input_kind(event: InputEvent) -> int:
	return _death_sequence_controller.resolve_input_kind(self, event)

func _apply_distortion_progress(progress: float) -> void:
	_screen_fx_controller.apply_distortion_progress(self, progress)

func _apply_transition_strength(strength: float) -> void:
	_screen_fx_controller.apply_transition_strength(self, strength)

func _advance_distortion(delta: float) -> void:
	_screen_fx_controller.advance_distortion(self, delta)

func _advance_transition(delta: float) -> void:
	_screen_fx_controller.advance_transition(self, delta)

func _ease_out(t: float) -> float:
	return _screen_fx_controller.ease_out(t)

func _is_distortion_allowed() -> bool:
	return _screen_fx_controller.is_distortion_allowed(self)

func _update_overlay_layer() -> void:
	_screen_fx_controller.update_overlay_layer(self)

func _hide_distortion_overlays() -> void:
	_screen_fx_controller.hide_distortion_overlays(self)

func _spawn_stalker_if_needed() -> void:
	_distortion_phase_controller.spawn_stalker_if_needed(self)

func _spawn_stalker_deferred(scene: Node, spawn_position: Vector2) -> void:
	_distortion_phase_controller.spawn_stalker_deferred(self, scene, spawn_position)

func _find_stalker_spawn(scene: Node) -> Node2D:
	return _distortion_phase_controller.find_stalker_spawn(self, scene)

func _connect_minigame_controller() -> void:
	if MinigameController == null:
		return
	if not MinigameController.minigame_started.is_connected(_on_minigame_started):
		MinigameController.minigame_started.connect(_on_minigame_started)
	if not MinigameController.minigame_finished.is_connected(_on_minigame_finished):
		MinigameController.minigame_finished.connect(_on_minigame_finished)

func _on_minigame_started(_minigame: Node) -> void:
	_distortion_phase_controller.on_minigame_started(self, _minigame)

func _on_minigame_finished(_minigame: Node, _success: bool) -> void:
	_distortion_phase_controller.on_minigame_finished(self, _minigame, _success)

func _minigame_allows_distortion(minigame: Node) -> bool:
	return _distortion_phase_controller.minigame_allows_distortion(minigame)

func get_cycle_number() -> int:
	return _current_cycle_number

func capture_checkpoint_state() -> Dictionary:
	return {
		"current_max_time": current_max_time,
		"current_cycle_number": _current_cycle_number,
		"current_timer_duration": _current_timer_duration,
		"time_left": get_time_left(),
		"timer_running": is_timer_running(),
		"pending_distortion_activation": _pending_distortion_activation,
		"stalker_spawned": _stalker_spawned,
		"distortion_active": _distortion_active,
		"distortion_progress": _distortion_progress,
		"transition_active": _transition_active,
		"transition_progress": _transition_progress,
	}

func apply_checkpoint_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_current_cycle_number = int(state.get("current_cycle_number", _current_cycle_number))
	_current_timer_duration = float(state.get("current_timer_duration", _current_timer_duration))
	current_max_time = float(state.get("current_max_time", current_max_time))
	_pending_distortion_activation = bool(state.get("pending_distortion_activation", false))
	_stalker_spawned = bool(state.get("stalker_spawned", false))
	_distortion_active = bool(state.get("distortion_active", false))
	_distortion_progress = float(state.get("distortion_progress", 0.0))
	_transition_active = bool(state.get("transition_active", false))
	_transition_progress = float(state.get("transition_progress", 0.0))
	_flash_active = false
	_damage_flash_active = false
	_stop_light_only_jump_effect()
	if _damage_rect != null:
		_damage_rect.visible = false
	_set_damage_intensity(0.0)
	if _death_sequence_active:
		_reset_death_screen_state()
	if CycleState != null and CycleState.phase == CycleState.Phase.NORMAL and current_max_time > 0.0:
		var timer_running := bool(state.get("timer_running", false))
		var time_left := clampf(float(state.get("time_left", current_max_time)), 0.0, current_max_time)
		if timer_running and time_left > 0.0:
			_timer.start(time_left)
		else:
			_timer.stop()
	else:
		_timer.stop()
	if not _distortion_active and not _transition_active:
		_hide_distortion_overlays()
	
