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

@export_group("Death Screen")
## Длительность затемнения до экрана смерти (сек).
@export_range(0.05, 3.0, 0.05) var death_fade_duration: float = 0.55
## Наклон камеры при смерти (градусы).
@export_range(0.0, 20.0, 0.1) var death_camera_tilt_deg: float = 5.0
## Множитель зума камеры при смерти.
@export_range(1.0, 2.5, 0.01) var death_camera_zoom_mult: float = 1.08
## Заголовок на экране смерти.
@export var death_title_text: String = "Убито"
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
var current_max_time: float = 1.0
var _current_cycle_number: int = 0
var _current_timer_duration: float = 0.0
var _distortion_active: bool = false
var _distortion_progress: float = 0.0
var _transition_active: bool = false
var _transition_progress: float = 0.0
var _flash_active: bool = false
var _damage_flash_active: bool = false
var _minigame_active: bool = false
var _minigame_blocks_distortion: bool = false
var _in_game_scene: bool = false
var _stalker_spawned: bool = false
var _death_layer: CanvasLayer
var _death_fade_rect: ColorRect
var _death_root: Control
var _death_title_label: Label
var _death_retry_button: Button
var _death_sequence_active: bool = false
var _death_camera: Camera2D = null
var _death_camera_base_rotation: float = 0.0
var _death_camera_base_zoom: Vector2 = Vector2.ONE
var _death_camera_base_offset: Vector2 = Vector2.ZERO

const STALKER_SPAWN_GROUP := "stalker_spawn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_timer.timeout.connect(_on_distortion_timeout)
	add_child(_timer)
	_create_distortion_overlay()
	_create_death_overlay()
	_connect_minigame_controller()
	if get_tree() and get_tree().has_signal("scene_changed"):
		get_tree().scene_changed.connect(_on_scene_changed)
	_update_for_scene(get_tree().current_scene)

func _process(delta: float) -> void:
	_update_overlay_layer()
	if _death_sequence_active:
		return
	if _distortion_rect == null or _distortion_material == null:
		return
	if not _is_distortion_allowed():
		_hide_distortion_overlays()
		return
	var has_active := false
	if _distortion_active:
		_distortion_rect.visible = true
		_advance_distortion(delta)
		has_active = true
	if _transition_active:
		_transition_rect.visible = true
		_advance_transition(delta)
		has_active = true
	if _damage_flash_active:
		has_active = true
	if _flash_active:
		return
	if not has_active:
		_hide_distortion_overlays()

func start_normal_phase(timer_duration: float = -1.0) -> void:
	GameState.set_phase(GameState.Phase.NORMAL)
	_distortion_active = false
	_distortion_progress = 0.0
	_transition_active = false
	_transition_progress = 0.0
	_flash_active = false
	_damage_flash_active = false
	_stalker_spawned = false
	_hide_distortion_overlays()
	
	var time_to_set: float = timer_duration
	if time_to_set < 0.0:
		time_to_set = default_time
	
	# Если время больше 0, запускаем таймер
	if time_to_set > 0.0:
		current_max_time = time_to_set
		_timer.start(time_to_set)
		print("GameDirector: Таймер запущен на %.1f сек." % time_to_set)
	else:
		# Если время 0 или меньше, останавливаем таймер (он не будет тикать)
		_timer.stop()
		current_max_time = 0.0 
		print("GameDirector: Таймер отключен для уровня.")

func reduce_time(amount: float, damage_flash: bool = false) -> void:
	if amount <= 0.0:
		return
	if not is_timer_running():
		return
	set_time_left(get_time_left() - amount)
	if GameState and GameState.phase != GameState.Phase.NORMAL:
		return
	if damage_flash:
		_flash_damage()
	else:
		_flash_red()

func _on_distortion_timeout() -> void:
	if GameState and GameState.phase == GameState.Phase.DISTORTED:
		return
	GameState.set_phase(GameState.Phase.DISTORTED)
	_distortion_active = true
	_distortion_progress = 0.0
	_transition_active = true
	_transition_progress = 0.0
	_flash_active = false
	_damage_flash_active = false
	if _damage_rect:
		_damage_rect.visible = false
	_set_damage_intensity(0.0)
	_distortion_rect.visible = _is_distortion_allowed()
	_transition_rect.visible = _is_distortion_allowed()
	_apply_distortion_progress(0.0)
	_apply_transition_strength(1.0)
	_spawn_stalker_if_needed()
	distortion_started.emit()

func get_time_ratio() -> float:
	if GameState.phase != GameState.Phase.NORMAL:
		return 0.0
	
	# Если таймер стоит в нормальной фазе — значит время бесконечное (100%)
	if _timer.is_stopped() or current_max_time <= 0.0:
		return 1.0
		
	return _timer.time_left / current_max_time

func get_time_left() -> float:
	if current_max_time <= 0.0:
		return 0.0
	if _timer.is_stopped():
		if GameState and GameState.phase == GameState.Phase.NORMAL:
			return current_max_time
		return 0.0
	return _timer.time_left

func is_timer_running() -> bool:
	if GameState and GameState.phase != GameState.Phase.NORMAL:
		return false
	return current_max_time > 0.0 and not _timer.is_stopped()

func ensure_timer_running(fallback_time: float) -> void:
	if fallback_time <= 0.0:
		return
	if GameState and GameState.phase != GameState.Phase.NORMAL:
		return
	if is_timer_running():
		return
	current_max_time = fallback_time
	_timer.start(fallback_time)

func set_time_left(new_time: float) -> void:
	if _death_sequence_active:
		return
	if GameState and GameState.phase != GameState.Phase.NORMAL:
		return
	if current_max_time <= 0.0:
		return
	var clamped_time: float = float(clamp(new_time, 0.0, current_max_time))
	if clamped_time <= 0.0:
		_timer.stop()
		_on_distortion_timeout()
		return
	_timer.start(clamped_time)

func _create_distortion_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 90
	add_child(_overlay_layer)
	
	_distortion_rect = ColorRect.new()
	_distortion_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_distortion_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_distortion_rect.visible = false
	_distortion_material = ShaderMaterial.new()
	_distortion_material.shader = preload("res://shaders/distortion_overlay.gdshader")
	_distortion_rect.material = _distortion_material
	_overlay_layer.add_child(_distortion_rect)
	_set_distortion_intensity(0.0)
	_set_distortion_squash(0.0)
	
	_transition_rect = ColorRect.new()
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.visible = false
	_transition_material = ShaderMaterial.new()
	_transition_material.shader = preload("res://shaders/distortion_transition.gdshader")
	_transition_rect.material = _transition_material
	_overlay_layer.add_child(_transition_rect)
	_set_transition_intensity(0.0)
	_set_transition_squash(0.0)

	_damage_rect = ColorRect.new()
	_damage_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_rect.visible = false
	_damage_material = ShaderMaterial.new()
	_damage_material.shader = preload("res://shaders/distortion_transition.gdshader")
	_damage_rect.material = _damage_material
	_overlay_layer.add_child(_damage_rect)
	_set_damage_intensity(0.0)
	_configure_damage_material()

func _flash_red() -> void:
	if _distortion_rect.visible:
		return
	if not _is_distortion_allowed():
		return
	_flash_active = true
	_distortion_rect.visible = true
	_set_distortion_intensity(0.25)
	_set_distortion_squash(0.0)
	get_tree().create_timer(0.1).timeout.connect(func():
		if GameState.phase == GameState.Phase.NORMAL:
			_distortion_rect.visible = false
			_set_distortion_intensity(0.0)
			_set_distortion_squash(0.0)
		_flash_active = false
	)

func _flash_damage() -> void:
	if _damage_rect == null or _damage_material == null:
		return
	if _damage_flash_active:
		return
	if not _is_distortion_allowed():
		return
	_damage_flash_active = true
	_configure_damage_material()
	_damage_rect.visible = true
	_set_damage_intensity(damage_flash_intensity)
	_apply_damage_camera_punch()
	get_tree().create_timer(damage_flash_duration).timeout.connect(func():
		if _damage_rect:
			_damage_rect.visible = false
			_set_damage_intensity(0.0)
		_damage_flash_active = false
	)

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
	_stalker_spawned = false
	_hide_distortion_overlays()
	if GameState:
		GameState.set_phase(GameState.Phase.NORMAL)

func _apply_level_settings(scene: Node) -> void:
	_current_cycle_number = _resolve_cycle_number(scene)
	_current_timer_duration = _resolve_timer_duration(scene)
	start_normal_phase(_current_timer_duration)

func _resolve_cycle_number(scene: Node) -> int:
	if scene == null:
		return 0
	if scene.has_method("get_cycle_number"):
		return int(scene.get_cycle_number())
	return 0

func _resolve_timer_duration(scene: Node) -> float:
	if scene == null:
		return default_time
	if scene.has_method("get_timer_duration"):
		return float(scene.get_timer_duration())
	return default_time

func _set_mouse_visibility(in_game: bool) -> void:
	if CursorManager:
		CursorManager.set_in_game(in_game)

func _create_death_overlay() -> void:
	_death_layer = CanvasLayer.new()
	_death_layer.layer = 120
	_death_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(_death_layer)

	_death_fade_rect = ColorRect.new()
	_death_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_fade_rect.color = Color(0, 0, 0, 0)
	_death_fade_rect.visible = false
	_death_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_fade_rect.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_death_layer.add_child(_death_fade_rect)

	_death_root = Control.new()
	_death_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_root.visible = false
	_death_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_death_layer.add_child(_death_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_root.add_child(center)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(content)

	_death_title_label = Label.new()
	_death_title_label.text = death_title_text
	_death_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_title_label.add_theme_font_size_override("font_size", 112)
	var base_font = load("res://global/fonts/AmaticSC-Regular.ttf")
	if base_font:
		var font_variation := FontVariation.new()
		font_variation.base_font = base_font
		font_variation.spacing_glyph = 3
		_death_title_label.add_theme_font_override("font", font_variation)
	content.add_child(_death_title_label)

	_death_retry_button = Button.new()
	_death_retry_button.text = death_retry_text
	_death_retry_button.custom_minimum_size = Vector2(420, 92)
	_death_retry_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_death_retry_button.pressed.connect(_on_death_retry_pressed)
	content.add_child(_death_retry_button)

func trigger_death_screen() -> void:
	if _death_sequence_active:
		return
	_death_sequence_active = true
	_timer.stop()
	_distortion_active = false
	_distortion_progress = 0.0
	_transition_active = false
	_transition_progress = 0.0
	_flash_active = false
	_damage_flash_active = false
	_hide_distortion_overlays()
	_death_camera = _resolve_primary_camera()
	if _death_camera != null:
		_death_camera_base_rotation = _death_camera.rotation
		_death_camera_base_zoom = _death_camera.zoom
		_death_camera_base_offset = _death_camera.offset
	if _death_title_label:
		_death_title_label.text = death_title_text
	if _death_retry_button:
		_death_retry_button.text = death_retry_text
	if _death_root:
		_death_root.visible = false
	if _death_fade_rect:
		_death_fade_rect.visible = true
		_death_fade_rect.color = Color(0, 0, 0, 0)
	var fade_time: float = maxf(0.01, death_fade_duration)
	var tween := create_tween()
	tween.set_parallel(true)
	if _death_fade_rect:
		tween.tween_property(_death_fade_rect, "color:a", 1.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _death_camera != null:
		var tilt_sign := -1.0 if randf() < 0.5 else 1.0
		var target_rotation := _death_camera_base_rotation + deg_to_rad(death_camera_tilt_deg) * tilt_sign
		var target_zoom := _death_camera_base_zoom * death_camera_zoom_mult
		tween.tween_property(_death_camera, "rotation", target_rotation, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(_death_camera, "zoom", target_zoom, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_death_fade_completed)

func _on_death_fade_completed() -> void:
	if not _death_sequence_active:
		return
	if _death_root:
		_death_root.visible = true
	if _death_retry_button:
		_death_retry_button.grab_focus()
	if get_tree():
		get_tree().paused = true

func _on_death_retry_pressed() -> void:
	if not _death_sequence_active:
		return
	if GameState:
		GameState.reset_cycle_state()
	_restore_death_camera()
	if _death_root:
		_death_root.visible = false
	if get_tree():
		get_tree().paused = false
		get_tree().call_deferred("reload_current_scene")

func _reset_death_screen_state() -> void:
	_death_sequence_active = false
	_restore_death_camera()
	if _death_root:
		_death_root.visible = false
	if _death_fade_rect:
		_death_fade_rect.visible = false
		_death_fade_rect.color = Color(0, 0, 0, 0)
	if get_tree() and get_tree().paused:
		get_tree().paused = false

func _restore_death_camera() -> void:
	if _death_camera != null and is_instance_valid(_death_camera):
		_death_camera.rotation = _death_camera_base_rotation
		_death_camera.zoom = _death_camera_base_zoom
		_death_camera.offset = _death_camera_base_offset
	_death_camera = null

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

func _configure_damage_material() -> void:
	if _damage_material == null:
		return
	_damage_material.set_shader_parameter("desaturation", damage_flash_desaturation)
	_damage_material.set_shader_parameter("shake_power", damage_flash_shake_power)
	_damage_material.set_shader_parameter("color_bleeding", damage_flash_color_bleeding)
	_damage_material.set_shader_parameter("glitch_lines", damage_flash_glitch_lines)
	_damage_material.set_shader_parameter("vignette_intensity", damage_flash_vignette_intensity)

func _apply_damage_camera_punch() -> void:
	if damage_flash_duration <= 0.0:
		return
	var camera := _resolve_primary_camera()
	if camera == null:
		return
	var base_zoom := camera.zoom
	var base_offset := camera.offset
	var base_rotation := camera.rotation
	var target_zoom := base_zoom * (1.0 + damage_flash_camera_zoom_punch)
	var jitter := Vector2(
		randf_range(-damage_flash_camera_offset_jitter, damage_flash_camera_offset_jitter),
		randf_range(-damage_flash_camera_offset_jitter, damage_flash_camera_offset_jitter)
	)
	var tilt_sign := -1.0 if randf() < 0.5 else 1.0
	var target_rotation := base_rotation + deg_to_rad(damage_flash_camera_tilt_deg) * tilt_sign
	var in_time: float = maxf(0.02, damage_flash_duration * 0.3)
	var out_time: float = maxf(0.02, damage_flash_duration * 0.7)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "zoom", target_zoom, in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "offset", base_offset + jitter, in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "rotation", target_rotation, in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(camera, "zoom", base_zoom, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(camera, "offset", base_offset, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(camera, "rotation", base_rotation, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _resolve_primary_camera() -> Camera2D:
	if get_viewport() and get_viewport().get_camera_2d():
		return get_viewport().get_camera_2d()
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	if player.has_node("Camera2D"):
		return player.get_node("Camera2D") as Camera2D
	return null

func _apply_distortion_progress(progress: float) -> void:
	var value: float = float(clamp(progress, 0.0, 1.0))
	_set_distortion_intensity(value)
	_set_distortion_squash(value * distortion_squash_amount)

func _apply_transition_strength(strength: float) -> void:
	var value: float = float(clamp(strength, 0.0, 1.0))
	# Мы убрали squash, так как новый шейдер делает всё через intensity
	_set_transition_intensity(value * distortion_transition_intensity)
	# _set_transition_squash(...) — эту строку можно удалить, она больше не нужна

func _advance_distortion(delta: float) -> void:
	if distortion_ramp_duration <= 0.0:
		_distortion_progress = 1.0
	elif _distortion_progress < 1.0:
		_distortion_progress = min(1.0, _distortion_progress + (delta / distortion_ramp_duration))
	var eased := _ease_out(_distortion_progress)
	_apply_distortion_progress(eased)

func _advance_transition(delta: float) -> void:
	if distortion_transition_duration <= 0.0:
		_transition_progress = 1.0
	elif _transition_progress < 1.0:
		_transition_progress = min(1.0, _transition_progress + (delta / distortion_transition_duration))
	var t: float = float(clamp(_transition_progress, 0.0, 1.0))
	var strength := pow(1.0 - t, 2.0)
	_apply_transition_strength(strength)
	if _transition_progress >= 1.0:
		_transition_active = false
		if _transition_rect:
			_transition_rect.visible = false

func _ease_out(t: float) -> float:
	var clamped: float = float(clamp(t, 0.0, 1.0))
	return 1.0 - pow(1.0 - clamped, 2.0)

func _is_distortion_allowed() -> bool:
	if not _in_game_scene:
		return false
	if _minigame_active and _minigame_blocks_distortion:
		return false
	return true

func _update_overlay_layer() -> void:
	if _overlay_layer == null:
		return
	var target_layer := 90
	var pause_menu_open := false
	if PauseManager and PauseManager.has_method("is_pause_menu_open"):
		pause_menu_open = PauseManager.is_pause_menu_open()
	if pause_menu_open or (get_tree() and get_tree().paused and not _minigame_active):
		target_layer = 70
	elif _minigame_active and MinigameController and MinigameController.has_method("get_active_minigame_layer"):
		target_layer = clampi(MinigameController.get_active_minigame_layer() - 1, 0, 89)
	if _overlay_layer.layer != target_layer:
		_overlay_layer.layer = target_layer

func _hide_distortion_overlays() -> void:
	if _distortion_rect:
		_distortion_rect.visible = false
	if _transition_rect:
		_transition_rect.visible = false
	if _damage_rect and not _damage_flash_active:
		_damage_rect.visible = false
	_set_distortion_intensity(0.0)
	_set_distortion_squash(0.0)
	_set_transition_intensity(0.0)
	_set_transition_squash(0.0)
	if not _damage_flash_active:
		_set_damage_intensity(0.0)

func _spawn_stalker_if_needed() -> void:
	if _stalker_spawned:
		return
	if not _in_game_scene:
		return
	if stalker_scene == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var spawn := _find_stalker_spawn(scene)
	if spawn == null:
		return
	var stalker := stalker_scene.instantiate()
	if stalker == null:
		return
	scene.add_child(stalker)
	if stalker is Node2D:
		(stalker as Node2D).global_position = spawn.global_position
	_stalker_spawned = true

func _find_stalker_spawn(scene: Node) -> Node2D:
	var nodes := get_tree().get_nodes_in_group(STALKER_SPAWN_GROUP)
	for node in nodes:
		if node is Node2D and scene.is_ancestor_of(node):
			return node
	return null

func _connect_minigame_controller() -> void:
	if MinigameController == null:
		return
	if MinigameController.has_signal("minigame_started") and not MinigameController.minigame_started.is_connected(_on_minigame_started):
		MinigameController.minigame_started.connect(_on_minigame_started)
	if MinigameController.has_signal("minigame_finished") and not MinigameController.minigame_finished.is_connected(_on_minigame_finished):
		MinigameController.minigame_finished.connect(_on_minigame_finished)

func _on_minigame_started(_minigame: Node) -> void:
	_minigame_active = true
	_minigame_blocks_distortion = not _minigame_allows_distortion(_minigame)

func _on_minigame_finished(_minigame: Node, _success: bool) -> void:
	_minigame_active = false
	_minigame_blocks_distortion = false

func _minigame_allows_distortion(minigame: Node) -> bool:
	if minigame == null:
		return true
	if minigame.has_method("allows_distortion_overlay"):
		return bool(minigame.allows_distortion_overlay())
	if minigame.has_meta("allow_distortion_overlay"):
		return bool(minigame.get_meta("allow_distortion_overlay"))
	return true

func get_cycle_number() -> int:
	return _current_cycle_number
	
