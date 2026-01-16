extends Control

signal unlocked

## Код, который нужно ввести.
@export var code_value: String = "1234"

const TITLE_FONT_SIZE: int = 64
const DISPLAY_FONT_SIZE: int = 64
const BODY_FONT_SIZE: int = 32
const BUTTON_FONT_SIZE: int = 40

var _current_input: String = ""
var _prev_mouse_mode: int = Input.MOUSE_MODE_VISIBLE

@onready var title_label: Label = $Center/PanelRoot/ContentMargin/VBox/Title
@onready var display_label: Label = $Center/PanelRoot/ContentMargin/VBox/DisplayPanel/Display
@onready var info_label: Label = $Center/PanelRoot/ContentMargin/VBox/Info
@onready var keypad_grid: GridContainer = $Center/PanelRoot/ContentMargin/VBox/KeypadPanel/Grid
@onready var ok_button: Button = $Center/PanelRoot/ContentMargin/VBox/ActionPanel/Buttons/OkButton
@onready var clear_button: Button = $Center/PanelRoot/ContentMargin/VBox/ActionPanel/Buttons/ClearButton
@onready var cancel_button: Button = $Center/PanelRoot/ContentMargin/VBox/ActionPanel/Buttons/CancelButton

func _ready() -> void:
	add_to_group("minigame_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_theme()
	_update_display()
	
	for button in keypad_grid.get_children():
		if button is Button:
			button.pressed.connect(func(): _on_button_pressed(button.text))
	
	ok_button.pressed.connect(_on_ok_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

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

func _exit_tree() -> void:
	Input.set_mouse_mode(_prev_mouse_mode)

func _apply_theme() -> void:
	var regular_font := load("res://fonts/AmaticSC-Regular.ttf")
	if regular_font == null:
		return
	var bold_font := load("res://fonts/AmaticSC-Bold.ttf")
	var theme := Theme.new()

	var body_font := FontVariation.new()
	body_font.base_font = regular_font
	body_font.spacing_glyph = 2
	theme.set_font("font", "Label", body_font)
	theme.set_font_size("font_size", "Label", BODY_FONT_SIZE)
	theme.set_font("font", "Button", body_font)
	theme.set_font_size("font_size", "Button", BUTTON_FONT_SIZE)
	set_theme(theme)

	var title_font := FontVariation.new()
	title_font.base_font = bold_font if bold_font else regular_font
	title_font.spacing_glyph = 3
	if title_label:
		title_label.add_theme_font_override("font", title_font)
		title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	if display_label:
		display_label.add_theme_font_override("font", title_font)
		display_label.add_theme_font_size_override("font_size", DISPLAY_FONT_SIZE)

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
