extends Node

# --- НАСТРОЙКИ ---
var cycle_settings: Dictionary = {
	1: 60.0,
	2: 45.0,
	3: 30.0,
	4: 20.0
}
@export var default_time: float = 15.0 

# --- ВНУТРЕННИЕ ПЕРЕМЕННЫЕ ---
var _timer: Timer
var _overlay_layer: CanvasLayer
var _red_rect: ColorRect

# Новая переменная: запоминает полную длительность текущего цикла
var current_max_time: float = 1.0 

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_distortion_timeout)
	add_child(_timer)

	_create_distortion_overlay()
	start_normal_phase()

func start_normal_phase() -> void:
	GameState.set_phase(GameState.Phase.NORMAL)
	_red_rect.visible = false
	
	var current_cycle = GameState.cycle
	var time_to_set: float = cycle_settings.get(current_cycle, default_time)
	
	# Запоминаем максимум, чтобы часы могли считать пропорцию
	current_max_time = time_to_set 
	
	_timer.start(time_to_set)
	print("GameDirector: Старт цикла %d. Таймер: %.1f сек." % [current_cycle, time_to_set])

func reduce_time(amount: float) -> void:
	if _timer.is_stopped(): return
	
	var new_time = _timer.time_left - amount
	
	if new_time <= 0.0:
		_timer.stop()
		_on_distortion_timeout()
	else:
		_timer.start(new_time)
		_flash_red()
		print("Время уменьшено. Осталось: ", new_time)

func _on_distortion_timeout() -> void:
	GameState.set_phase(GameState.Phase.DISTORTED)
	UIMessage.show_text("РЕАЛЬНОСТЬ ИСКАЖЕНА")
	_red_rect.visible = true
	print("GameDirector: ФАЗА ИСКАЖЕНИЯ")

# --- ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ДЛЯ ЧАСОВ ---
# Возвращает число от 0.0 до 1.0 (процент оставшегося времени)
func get_time_ratio() -> float:
	if GameState.current_phase != GameState.Phase.NORMAL:
		return 0.0 # Если фаза искажена, время вышло (0%)
	if _timer.is_stopped():
		return 0.0
	# Делим оставшееся время на изначальное время цикла
	return _timer.time_left / current_max_time

# --- ВИЗУАЛ ---
func _create_distortion_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 90
	add_child(_overlay_layer)
	
	_red_rect = ColorRect.new()
	_red_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_red_rect.color = Color(1.0, 0.0, 0.0, 0.3)
	_red_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red_rect.visible = false
	_overlay_layer.add_child(_red_rect)

func _flash_red() -> void:
	if _red_rect.visible: return
	_red_rect.visible = true
	_red_rect.color.a = 0.1
	get_tree().create_timer(0.1).timeout.connect(func(): 
		if GameState.current_phase == GameState.Phase.NORMAL:
			_red_rect.visible = false
			_red_rect.color.a = 0.3
	)
	
