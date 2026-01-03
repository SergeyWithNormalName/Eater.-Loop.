extends Button

var text_value: String = ""
var grab_radius: float = 60.0

static var is_any_dragging: bool = false

var _is_dragging: bool = false
var _ghost: Button = null
var _drag_layer: Control = null

func _ready():
	text = text_value
	custom_minimum_size = Vector2(80, 40) # Примерный размер
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_drag_context(drag_layer: Control) -> void:
	_drag_layer = drag_layer

func _input(event: InputEvent) -> void:
	if _is_grab_pressed(event):
		if is_any_dragging or _drag_layer == null:
			return
		
		var mouse_pos = get_global_mouse_position()
		if _is_point_over_self(mouse_pos):
			_start_drag(mouse_pos)
	elif _is_grab_released(event) and _is_dragging:
		_end_drag()

func _process(_delta: float) -> void:
	if _is_dragging and _ghost:
		_ghost.global_position = get_global_mouse_position() - _ghost.size * 0.5

func _start_drag(mouse_pos: Vector2) -> void:
	_is_dragging = true
	is_any_dragging = true
	
	_ghost = Button.new()
	_ghost.text = text
	_ghost.custom_minimum_size = custom_minimum_size
	_ghost.size = size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	_ghost.focus_mode = Control.FOCUS_NONE
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 1000
	_drag_layer.add_child(_ghost)
	_ghost.global_position = mouse_pos - _ghost.size * 0.5

func _end_drag() -> void:
	_is_dragging = false
	is_any_dragging = false
	
	var target_slot := _find_drop_slot()
	if target_slot and target_slot.can_accept_word(text_value):
		target_slot.set_word(text_value)
	
	if _ghost:
		_ghost.queue_free()
		_ghost = null

func _is_point_over_self(point: Vector2) -> bool:
	var rect := get_global_rect()
	return rect.has_point(point)

func _find_drop_slot() -> Node:
	var hovered := get_viewport().gui_get_hovered_control()
	var node: Node = hovered
	while node != null:
		if node.has_method("set_word") and node.has_method("can_accept_word"):
			return node
		node = node.get_parent()
	return null

func _is_grab_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("mg_grab") or event.is_action_pressed("mg_grap")

func _is_grab_released(event: InputEvent) -> bool:
	return event.is_action_released("mg_grab") or event.is_action_released("mg_grap")

func _exit_tree() -> void:
	if _is_dragging:
		is_any_dragging = false
	if _ghost:
		_ghost.queue_free()
		_ghost = null
