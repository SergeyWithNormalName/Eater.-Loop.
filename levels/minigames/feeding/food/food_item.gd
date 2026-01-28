extends Area2D

signal eaten

# Статика для блокировки (один пельмень в руку)
static var is_any_dragging: bool = false

var _is_dragging: bool = false
var _start_position: Vector2
var _grab_offset: Vector2 = Vector2.ZERO
var _target_mouth: Area2D = null

# Новый флаг: находится ли пельмень прямо сейчас над ртом?
var _is_over_mouth: bool = false


func _ready() -> void:
	_start_position = global_position
	input_pickable = true 
	is_any_dragging = false
	
	# Подключаем сигналы САМОГО ПЕЛЬМЕНЯ к самому себе
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func set_target_mouth(mouth: Area2D) -> void:
	_target_mouth = mouth

# --- ЛОГИКА ОПРЕДЕЛЕНИЯ "НАД РТОМ ЛИ МЫ" ---
func _on_area_entered(area: Area2D) -> void:
	# Если мы зашли в зону, которая является нашим целевым ртом
	if area == _target_mouth:
		_is_over_mouth = true

func _on_area_exited(area: Area2D) -> void:
	# Если вышли из зоны рта
	if area == _target_mouth:
		_is_over_mouth = false
# ---------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mg_grab"):
		if is_any_dragging:
			return

		var mouse_pos = get_global_mouse_position()
		if _is_point_over_self(mouse_pos):
			_start_drag(mouse_pos)
	elif event.is_action_released("mg_grab") and _is_dragging:
		_end_drag()

func _start_drag(mouse_pos: Vector2) -> void:
	_is_dragging = true
	is_any_dragging = true
	_grab_offset = global_position - mouse_pos
	z_index = 10
	
	var tween = get_tree().create_tween()
	tween.kill()

func _end_drag() -> void:
	_is_dragging = false
	is_any_dragging = false
	z_index = 0
	
	# Проверяем попадание даже при паузе дерева, без опоры на physics-сигналы.
	if _is_in_mouth():
		eat_me()
	else:
		_return_to_plate()

func _return_to_plate() -> void:
	var tween = create_tween()
	tween.tween_property(self, "global_position", _start_position, 0.3).set_trans(Tween.TRANS_ELASTIC)

func _process(_delta: float) -> void:
	if _is_dragging:
		global_position = get_global_mouse_position() + _grab_offset

func _is_point_over_self(point: Vector2) -> bool:
	for child in get_children():
		if child is CollisionShape2D and child.shape:
			if _is_point_in_shape(child, point):
				return true
	return false

func _is_point_in_shape(shape_node: CollisionShape2D, point: Vector2) -> bool:
	var local_point := shape_node.global_transform.affine_inverse() * point
	var shape := shape_node.shape
	
	if shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		return local_point.length_squared() <= radius * radius
	
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var radius := capsule.radius
		var half_height: float = max(0.0, capsule.height) * 0.5
		var dy: float = abs(local_point.y) - half_height
		if dy <= 0.0:
			return abs(local_point.x) <= radius
		return local_point.x * local_point.x + dy * dy <= radius * radius
	
	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		var half_size := rect.size * 0.5
		return abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y
	
	return false

func _is_in_mouth() -> bool:
	if _target_mouth == null:
		return false
	if _is_over_mouth:
		return true
	
	var shape_node: CollisionShape2D = null
	for child in _target_mouth.get_children():
		if child is CollisionShape2D and child.shape:
			shape_node = child
			break
	
	if shape_node == null:
		return false
	
	if shape_node.shape is CircleShape2D:
		var circle := shape_node.shape as CircleShape2D
		var shape_scale := shape_node.global_scale
		var radius: float = circle.radius * max(abs(shape_scale.x), abs(shape_scale.y))
		return global_position.distance_to(shape_node.global_position) <= radius
	
	# Фоллбек: если форма не круг, пробуем стандартную проверку.
	return _target_mouth.overlaps_area(self)

func eat_me() -> void:
	eaten.emit()
	queue_free()

func _exit_tree() -> void:
	if _is_dragging:
		is_any_dragging = false
