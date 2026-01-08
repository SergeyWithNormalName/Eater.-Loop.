extends Control

signal unlocked

## Код, который нужно ввести.
@export var code_value: String = "1234"

var _current_input: String = ""

@onready var display_label: Label = $Panel/VBox/Display
@onready var info_label: Label = $Panel/VBox/Info

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_update_display()
	
	for button in $Panel/VBox/Grid.get_children():
		if button is Button:
			button.pressed.connect(func(): _on_button_pressed(button.text))
	
	$Panel/VBox/Buttons/OkButton.pressed.connect(_on_ok_pressed)
	$Panel/VBox/Buttons/ClearButton.pressed.connect(_on_clear_pressed)
	$Panel/VBox/Buttons/CancelButton.pressed.connect(_on_cancel_pressed)

func _process(delta: float) -> void:
	_handle_gamepad_cursor(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		return
	if _is_grab_pressed(event):
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered is Button:
			hovered.emit_signal("pressed")

func _on_button_pressed(value: String) -> void:
	if _current_input.length() >= code_value.length():
		return
	_current_input += value
	_update_display()

func _on_ok_pressed() -> void:
	if _current_input == code_value:
		unlocked.emit()
		_close()
	else:
		info_label.text = "Неверный код"
		_current_input = ""
		_update_display()

func _on_clear_pressed() -> void:
	_current_input = ""
	info_label.text = ""
	_update_display()

func _on_cancel_pressed() -> void:
	_close()

func _update_display() -> void:
	display_label.text = _current_input

func _close() -> void:
	get_tree().paused = false
	queue_free()

func _handle_gamepad_cursor(delta: float) -> void:
	var joy_vector = Input.get_vector("mg_cursor_left", "mg_cursor_right", "mg_cursor_up", "mg_cursor_down")
	if joy_vector.length() > 0.1:
		var current_mouse = get_viewport().get_mouse_position()
		var new_pos = current_mouse + joy_vector * 800.0 * delta
		var screen_rect = get_viewport().get_visible_rect().size
		new_pos.x = clamp(new_pos.x, 0, screen_rect.x)
		new_pos.y = clamp(new_pos.y, 0, screen_rect.y)
		get_viewport().warp_mouse(new_pos)

func _is_grab_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("mg_grab")
