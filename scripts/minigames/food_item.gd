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

@export var grab_radius: float = 60.0

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
		if global_position.distance_to(mouse_pos) < grab_radius:
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
	
	# ИСПРАВЛЕНИЕ: Проверяем флаг, который мы обновляли сигналами. 
	# Это работает на 100% надежно.
	if _is_over_mouth:
		eat_me()
	else:
		_return_to_plate()

func _return_to_plate() -> void:
	var tween = create_tween()
	tween.tween_property(self, "global_position", _start_position, 0.3).set_trans(Tween.TRANS_ELASTIC)

func _process(_delta: float) -> void:
	if _is_dragging:
		global_position = get_global_mouse_position() + _grab_offset

func eat_me() -> void:
	eaten.emit()
	queue_free()

func _exit_tree() -> void:
	if _is_dragging:
		is_any_dragging = false
