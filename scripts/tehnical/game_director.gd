extends Node

signal distortion_started

## Время по умолчанию, если на уровне не задано.
@export var default_time: float = 15.0

var _timer: Timer
var _overlay_layer: CanvasLayer
var _distortion_rect: ColorRect
var _distortion_material: ShaderMaterial
var current_max_time: float = 1.0
var _current_cycle_number: int = 0
var _current_timer_duration: float = 0.0

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_distortion_timeout)
	add_child(_timer)
	_create_distortion_overlay()
	if get_tree() and get_tree().has_signal("scene_changed"):
		get_tree().scene_changed.connect(_on_scene_changed)
	_update_for_scene(get_tree().current_scene)

func start_normal_phase(timer_duration: float = -1.0) -> void:
	GameState.set_phase(GameState.Phase.NORMAL)
	_set_distortion_intensity(0.0)
	_distortion_rect.visible = false
	
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
	UIMessage.show_text("РЕАЛЬНОСТЬ ИСКАЖЕНА")
	_set_distortion_intensity(1.0)
	_distortion_rect.visible = true
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

func _flash_red() -> void:
	if _distortion_rect.visible:
		return
	_distortion_rect.visible = true
	_set_distortion_intensity(0.25)
	get_tree().create_timer(0.1).timeout.connect(func():
		if GameState.phase == GameState.Phase.NORMAL:
			_distortion_rect.visible = false
			_set_distortion_intensity(0.0)
	)

func _on_scene_changed(scene: Node = null) -> void:
	if scene == null:
		scene = get_tree().current_scene
	_update_for_scene(scene)

func _update_for_scene(scene: Node) -> void:
	var path := scene.scene_file_path if scene else ""
	var in_game := path.find("/scenes/cycles/") != -1
	_set_mouse_visibility(in_game)
	if in_game:
		_apply_level_settings(scene)
		return
	_timer.stop()
	_set_distortion_intensity(0.0)
	_distortion_rect.visible = false
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

func get_cycle_number() -> int:
	return _current_cycle_number
	
