extends Control


signal unlocked

## Код, который нужно ввести.
@export var code_value: String = "1234"

const TITLE_FONT_SIZE: int = 64
const DISPLAY_FONT_SIZE: int = 64
const BODY_FONT_SIZE: int = 32
const BUTTON_FONT_SIZE: int = 40

var _current_input: String = ""
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
	_start_minigame_session()
	_apply_theme()
	_update_display()
	
	for button in keypad_grid.get_children():
		if button is Button:
			button.pressed.connect(func(): _on_button_pressed(button.text))
	
	ok_button.pressed.connect(_on_ok_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

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
		_close(true)
	else:
		info_label.text = "Неверный код"
		_current_input = ""
		_update_display()

func _on_clear_pressed() -> void:
	_current_input = ""
	info_label.text = ""
	_update_display()

func _on_cancel_pressed() -> void:
	_close(false)

func _update_display() -> void:
	display_label.text = _current_input

func _close(success: bool) -> void:
	if MinigameController:
		MinigameController.finish_minigame_with_fade(self, success, func():
			queue_free()
		)
	else:
		queue_free()

func _exit_tree() -> void:
	if MinigameController:
		if MinigameController.is_active(self):
			MinigameController.finish_minigame(self, false)

func _apply_theme() -> void:
	var regular_font := load("res://global/fonts/AmaticSC-Regular.ttf")
	if regular_font == null:
		return
	var bold_font := load("res://global/fonts/AmaticSC-Bold.ttf")
	var ui_theme := Theme.new()

	var body_font := FontVariation.new()
	body_font.base_font = regular_font
	body_font.spacing_glyph = 2
	ui_theme.set_font("font", "Label", body_font)
	ui_theme.set_font_size("font_size", "Label", BODY_FONT_SIZE)
	ui_theme.set_font("font", "Button", body_font)
	ui_theme.set_font_size("font_size", "Button", BUTTON_FONT_SIZE)
	set_theme(ui_theme)

	var title_font := FontVariation.new()
	title_font.base_font = bold_font if bold_font else regular_font
	title_font.spacing_glyph = 3
	if title_label:
		title_label.add_theme_font_override("font", title_font)
		title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	if display_label:
		display_label.add_theme_font_override("font", title_font)
		display_label.add_theme_font_size_override("font_size", DISPLAY_FONT_SIZE)

func _start_minigame_session() -> void:
	if MinigameController == null:
		return
	var settings := MinigameSettings.new()
	settings.pause_game = false
	settings.enable_gamepad_cursor = true
	settings.gamepad_cursor_speed = 800.0
	settings.block_player_movement = true
	settings.allow_pause_menu = false
	settings.allow_cancel_action = true
	if not MinigameController.is_active(self):
		MinigameController.start_minigame(self, settings)

func on_minigame_cancel() -> void:
	_close(false)

func _is_grab_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("mg_grab")

func allows_distortion_overlay() -> bool:
	return true
