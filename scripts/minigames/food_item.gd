extends Area2D

signal eaten

var _is_dragging: bool = false
var _start_position: Vector2
var _grab_offset: Vector2 = Vector2.ZERO

# Радиус, в котором еду можно схватить (если коллизия маленькая)
@export var grab_radius: float = 60.0

func _ready() -> void:
	_start_position = global_position
	# Включаем мониторинг мыши
	input_pickable = true 

func _input(event: InputEvent) -> void:
	# Логика нажатия
	if event.is_action_pressed("mg_grab"):
		# Проверяем, близко ли курсор к этому пельменю
		var mouse_pos = get_global_mouse_position()
		if global_position.distance_to(mouse_pos) < grab_radius:
			_is_dragging = true
			_grab_offset = global_position - mouse_pos
			# Поднимаем пельмень визуально наверх (чтобы не перекрывался другими)
			z_index = 10

	# Логика отпускания
	elif event.is_action_released("mg_grab") and _is_dragging:
		_is_dragging = false
		z_index = 0 # Возвращаем слой
		
		# Если отпустили не во рту (рот сам удалит еду), возвращаем на место
		# Можно добавить плавную анимацию возврата:
		var tween = create_tween()
		tween.tween_property(self, "global_position", _start_position, 0.3).set_trans(Tween.TRANS_ELASTIC)

func _process(_delta: float) -> void:
	if _is_dragging:
		global_position = get_global_mouse_position() + _grab_offset

func eat_me() -> void:
	eaten.emit()
	queue_free()
	
