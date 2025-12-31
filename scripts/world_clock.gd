extends Node2D

@onready var label: Label = $Label

# Время, которое показывают часы в начале цикла (Часы:Минуты)
@export var start_game_time: String = "01:20" 

var _total_game_minutes: float = 0.0

func _ready() -> void:
	# Парсим строку "01:20" в число минут (1*60 + 20 = 80)
	var parts = start_game_time.split(":")
	if parts.size() == 2:
		var hours = int(parts[0])
		var minutes = int(parts[1])
		_total_game_minutes = (hours * 60) + minutes
	else:
		push_error("Неверный формат времени в WorldClock! Используй ЧЧ:ММ")
		_total_game_minutes = 60.0 # Дефолт, если ошибка

func _process(_delta: float) -> void:
	# 1. Получаем процент оставшегося реального времени (от 1.0 до 0.0)
	var ratio = GameDirector.get_time_ratio()
	
	# 2. Вычисляем текущее игровое время
	var current_minutes_left = _total_game_minutes * ratio
	
	# 3. Переводим обратно в часы и минуты
	# floor() округляет вниз, чтобы 0:00 наступило ровно в конце
	var display_h = floor(current_minutes_left / 60) 
	var display_m = floor(fmod(current_minutes_left, 60))
	
	# 4. Обновляем текст (формат 0:00)
	label.text = "%d:%02d" % [display_h, display_m]
	
	# (Опционально) Меняем цвет на красный, когда мало времени
	if ratio < 0.2:
		label.modulate = Color(1, 0, 0)
	else:
		label.modulate = Color(1, 1, 1)
