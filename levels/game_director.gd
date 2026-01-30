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

var _timer: Timer
var _overlay_layer: CanvasLayer
var _distortion_rect: ColorRect
var _distortion_material: ShaderMaterial
var _transition_rect: ColorRect
var _transition_material: ShaderMaterial
var current_max_time: float = 1.0
var _current_cycle_number: int = 0
var _current_timer_duration: float = 0.0
var _distortion_active: bool = false
var _distortion_progress: float = 0.0
var _transition_active: bool = false
var _transition_progress: float = 0.0
var _flash_active: bool = false
var _minigame_active: bool = false
var _minigame_blocks_distortion: bool = false
var _in_game_scene: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_timer.timeout.connect(_on_distortion_timeout)
	add_child(_timer)
	_create_distortion_overlay()
	_connect_minigame_controller()
	if get_tree() and get_tree().has_signal("scene_changed"):
		get_tree().scene_changed.connect(_on_scene_changed)
	_update_for_scene(get_tree().current_scene)

func _process(delta: float) -> void:
	_update_overlay_layer()
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

func reduce_time(amount: float) -> void:
	# Если таймер не запущен (бесконечное время), урон по времени не наносится
	if _timer.is_stopped() or current_max_time <= 0.0: 
		return
		
	var new_time = _timer.time_left - amount
	if new_time <= 0.0:
		_timer.stop()
		_on_distortion_timeout()
	else:
		_timer.start(new_time)
		_flash_red()

func _on_distortion_timeout() -> void:
	GameState.set_phase(GameState.Phase.DISTORTED)
	_distortion_active = true
	_distortion_progress = 0.0
	_transition_active = true
	_transition_progress = 0.0
	_flash_active = false
	_distortion_rect.visible = _is_distortion_allowed()
	_transition_rect.visible = _is_distortion_allowed()
	_apply_distortion_progress(0.0)
	_apply_transition_strength(1.0)
	distortion_started.emit()

func get_time_ratio() -> float:
	if GameState.phase != GameState.Phase.NORMAL:
		return 0.0
	
	# Если таймер стоит в нормальной фазе — значит время бесконечное (100%)
	if _timer.is_stopped() or current_max_time <= 0.0:
		return 1.0
		
	return _timer.time_left / current_max_time

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

func _on_scene_changed(scene: Node = null) -> void:
	if scene == null:
		scene = get_tree().current_scene
	_update_for_scene(scene)

func _update_for_scene(scene: Node) -> void:
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
	_set_distortion_intensity(0.0)
	_set_distortion_squash(0.0)
	_set_transition_intensity(0.0)
	_set_transition_squash(0.0)

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
	
