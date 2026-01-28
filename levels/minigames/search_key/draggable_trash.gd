extends TextureRect

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_offset = global_position - get_global_mouse_position()
				move_to_front()
			else:
				_is_dragging = false
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _is_dragging:
		global_position = get_global_mouse_position() + _drag_offset
		get_viewport().set_input_as_handled()
