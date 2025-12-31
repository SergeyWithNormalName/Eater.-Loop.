extends Area2D

# Сигнал, который мы отправим мини-игре, когда еда попадет в рот
signal eaten

var _is_dragging: bool = false
var _start_position: Vector2

func _ready() -> void:
	# Запоминаем, где еда появилась, чтобы если игрок отпустил её мимо рта, она вернулась
	_start_position = global_position
	# Включаем обработку мыши
	input_pickable = true 

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Если нажали кнопку действия (mg_grab) или левую кнопку мыши по предмету
	if event.is_action_pressed("mg_grab"):
		_is_dragging = true

func _input(event: InputEvent) -> void:
	# Если отпустили кнопку — перестаем тащить
	if event.is_action_released("mg_grab") and _is_dragging:
		_is_dragging = false
		# Возвращаем на место (можно добавить анимацию tween, но пока так)
		global_position = _start_position

func _process(_delta: float) -> void:
	if _is_dragging:
		# Следим за курсором
		global_position = get_global_mouse_position()

func eat_me() -> void:
	# Эту функцию вызовет "Рот" Андрея
	eaten.emit()
	queue_free() 
	
