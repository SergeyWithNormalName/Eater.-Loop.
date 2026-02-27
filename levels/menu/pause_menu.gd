extends "res://levels/menu/menu_base.gd"

signal resume_requested

@export_group("Сцены")
## Сцена главного меню.
@export var main_menu_scene: PackedScene

@export_group("Музыка")
## Музыка меню паузы.
@export var menu_music: AudioStream
## Громкость музыки меню (дБ).
@export_range(-80.0, 6.0, 0.1) var menu_music_volume_db: float = -12.0
## Длительность быстрого затухания остальной музыки (сек).
@export_range(0.0, 10.0, 0.1) var menu_music_fade_time: float = 1.0
## Длительность возврата музыки погони после паузы (сек).
@export_range(0.0, 10.0, 0.1) var chase_music_resume_fade_time: float = 0.1

const EXIT_WARNING := "Вы уверены, что хотите выйти? В следующий раз вам придётся проснуться снова..."

@onready var _title_label: Label = $MainPanelCenter/MainPanel/VBox/Title
@onready var _resume_button: Button = $MainPanelCenter/MainPanel/VBox/Buttons/ResumeButton
@onready var _settings_button: Button = $MainPanelCenter/MainPanel/VBox/Buttons/SettingsButton
@onready var _exit_menu_button: Button = $MainPanelCenter/MainPanel/VBox/Buttons/ExitMenuButton
@onready var _exit_game_button: Button = $MainPanelCenter/MainPanel/VBox/Buttons/ExitGameButton

@onready var _main_panel: Control = $MainPanelCenter/MainPanel
@onready var _settings_panel: Control = $SettingsPanelCenter/SettingsPanel

@onready var _confirm_panel: Control = $ConfirmPanelCenter/ConfirmPanel
@onready var _confirm_label: Label = $ConfirmPanelCenter/ConfirmPanel/VBox/Message
@onready var _confirm_yes: Button = $ConfirmPanelCenter/ConfirmPanel/VBox/Buttons/YesButton
@onready var _confirm_no: Button = $ConfirmPanelCenter/ConfirmPanel/VBox/Buttons/NoButton

var _confirm_action: Callable
const PANEL_MAIN := "main"
const PANEL_SETTINGS := "settings"
var _active_panel: String = PANEL_MAIN
var _panel_before_confirm: String = PANEL_MAIN

func _ready() -> void:
	super._ready()
	apply_title_style(_title_label)
	_apply_pause_visual_style()
	_connect_buttons()
	_show_main()

func _apply_pause_visual_style() -> void:
	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color(0.08, 0.08, 0.08, 0.42)
	button_normal.border_width_left = 1
	button_normal.border_width_top = 1
	button_normal.border_width_right = 1
	button_normal.border_width_bottom = 1
	button_normal.border_color = Color(0.78, 0.78, 0.78, 0.34)
	button_normal.corner_radius_top_left = 10
	button_normal.corner_radius_top_right = 10
	button_normal.corner_radius_bottom_right = 10
	button_normal.corner_radius_bottom_left = 10
	button_normal.content_margin_left = 24.0
	button_normal.content_margin_top = 12.0
	button_normal.content_margin_right = 24.0
	button_normal.content_margin_bottom = 14.0

	var button_hover := button_normal.duplicate() as StyleBoxFlat
	button_hover.bg_color = Color(0.13, 0.13, 0.13, 0.72)
	button_hover.border_color = Color(0.9, 0.9, 0.9, 0.66)

	var button_focus := button_normal.duplicate() as StyleBoxFlat
	button_focus.bg_color = Color(0.16, 0.16, 0.16, 0.74)
	button_focus.border_color = Color(1, 1, 1, 0.94)
	button_focus.shadow_color = Color(0.86, 0.86, 0.86, 0.14)
	button_focus.shadow_size = 8

	var button_pressed := button_normal.duplicate() as StyleBoxFlat
	button_pressed.bg_color = Color(0.22, 0.22, 0.22, 0.84)
	button_pressed.border_color = Color(1, 1, 1, 0.98)

	var button_disabled := button_normal.duplicate() as StyleBoxFlat
	button_disabled.bg_color = Color(0.06, 0.06, 0.06, 0.22)
	button_disabled.border_color = Color(0.56, 0.56, 0.56, 0.2)

	var buttons := find_children("*", "Button", true, false)
	for node in buttons:
		var button := node as Button
		if button == null:
			continue
		if not button.is_in_group("menu_button"):
			continue
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 72.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_stylebox_override("normal", button_normal)
		button.add_theme_stylebox_override("hover", button_hover)
		button.add_theme_stylebox_override("focus", button_focus)
		button.add_theme_stylebox_override("pressed", button_pressed)
		button.add_theme_stylebox_override("disabled", button_disabled)
		button.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93, 0.98))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		button.add_theme_color_override("font_disabled_color", Color(0.56, 0.56, 0.56, 0.86))

	_confirm_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 0.96))
	_confirm_label.add_theme_font_size_override("font_size", body_font_size + 2)
	_style_settings_panel()

func _style_settings_panel() -> void:
	var settings_title := _settings_panel.get_node_or_null("VBox/Title") as Label
	if settings_title != null:
		settings_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 0.98))

	var sound_title := _settings_panel.get_node_or_null("VBox/Content/SoundTitle") as Label
	if sound_title != null:
		sound_title.add_theme_color_override("font_color", Color(0.84, 0.84, 0.84, 0.92))

	var graphics_title := _settings_panel.get_node_or_null("VBox/Content/GraphicsTitle") as Label
	if graphics_title != null:
		graphics_title.add_theme_color_override("font_color", Color(0.84, 0.84, 0.84, 0.92))

	var row_labels := [
		"VBox/Content/MasterRow/MasterLabel",
		"VBox/Content/MusicRow/MusicLabel",
		"VBox/Content/SfxRow/SfxLabel"
	]
	for label_path in row_labels:
		var row_label := _settings_panel.get_node_or_null(label_path) as Label
		if row_label == null:
			continue
		row_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93, 0.95))

	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color(0.24, 0.24, 0.24, 0.78)
	slider_track.corner_radius_top_left = 4
	slider_track.corner_radius_top_right = 4
	slider_track.corner_radius_bottom_right = 4
	slider_track.corner_radius_bottom_left = 4

	var slider_fill := slider_track.duplicate() as StyleBoxFlat
	slider_fill.bg_color = Color(0.88, 0.88, 0.88, 0.84)

	var sliders := _settings_panel.find_children("*", "HSlider", true, false)
	for node in sliders:
		var slider := node as HSlider
		if slider == null:
			continue
		slider.custom_minimum_size.x = maxf(slider.custom_minimum_size.x, 340.0)
		slider.add_theme_stylebox_override("grabber_area", slider_track)
		slider.add_theme_stylebox_override("grabber_area_highlight", slider_fill)

	var checks := _settings_panel.find_children("*", "CheckBox", true, false)
	for node in checks:
		var check := node as CheckBox
		if check == null:
			continue
		check.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93, 0.95))
		check.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		check.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		check.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))

func _unhandled_input(event: InputEvent) -> void:
	if activate_focused_menu_button_on_accept(event):
		return
	var pause_requested := event.is_action_pressed("pause_menu")
	var escape_requested := event.is_action_pressed("ui_cancel") and _is_keyboard_escape_event(event)
	if not pause_requested and not escape_requested:
		return
	if _confirm_panel.visible:
		_hide_confirm()
		get_viewport().set_input_as_handled()
		return
	if _settings_panel.visible:
		_hide_settings()
		get_viewport().set_input_as_handled()
		return
	_resume()
	get_viewport().set_input_as_handled()

func _is_keyboard_escape_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.physical_keycode == KEY_ESCAPE or key_event.keycode == KEY_ESCAPE

func open_menu() -> void:
	visible = true
	_show_main()
	_play_menu_music()

func close_menu() -> void:
	visible = false
	_hide_confirm()
	_hide_settings()

func request_resume() -> void:
	_resume()

func _connect_buttons() -> void:
	_resume_button.pressed.connect(_resume)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_menu_button.pressed.connect(_on_exit_menu_pressed)
	_exit_game_button.pressed.connect(_on_exit_game_pressed)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_hide_confirm)
	if _settings_panel.has_signal("closed"):
		_settings_panel.connect("closed", _hide_settings)

func _show_main() -> void:
	_active_panel = PANEL_MAIN
	_main_panel.visible = true
	_settings_panel.visible = false
	_confirm_panel.visible = false
	_resume_button.grab_focus()

func _resume() -> void:
	_restore_menu_music()
	emit_signal("resume_requested")

func _on_settings_pressed() -> void:
	_active_panel = PANEL_SETTINGS
	_main_panel.visible = false
	_settings_panel.visible = true
	_confirm_panel.visible = false
	if _settings_panel.has_method("focus_default"):
		_settings_panel.call("focus_default")

func _on_exit_menu_pressed() -> void:
	_show_confirm(EXIT_WARNING, _exit_to_menu)

func _on_exit_game_pressed() -> void:
	_show_confirm(EXIT_WARNING, _exit_game)

func _exit_to_menu() -> void:
	if main_menu_scene == null:
		push_warning("PauseMenu: не назначена сцена главного меню.")
		return
	if GameState:
		GameState.reset_cycle_state()
	_stop_menu_music()
	await UIMessage.change_scene_with_fade(main_menu_scene, 0.5, true)

func _exit_game() -> void:
	_stop_menu_music()
	get_tree().paused = false
	get_tree().quit()

func _show_confirm(message: String, action: Callable) -> void:
	_panel_before_confirm = _active_panel
	_confirm_label.text = message
	_confirm_action = action
	_main_panel.visible = false
	_settings_panel.visible = false
	_confirm_panel.visible = true
	_confirm_yes.grab_focus()

func _hide_confirm() -> void:
	_confirm_panel.visible = false
	_confirm_action = Callable()
	_restore_panel_after_confirm()

func _on_confirm_yes() -> void:
	_confirm_panel.visible = false
	var action := _confirm_action
	_confirm_action = Callable()
	if action.is_valid():
		action.call()
	else:
		_restore_panel_after_confirm()

func _hide_settings() -> void:
	_show_main()

func _restore_panel_after_confirm() -> void:
	match _panel_before_confirm:
		PANEL_SETTINGS:
			_on_settings_pressed()
		_:
			_show_main()

func _play_menu_music() -> void:
	if MusicManager == null:
		return
	MusicManager.start_pause_menu_music(menu_music, menu_music_fade_time, menu_music_volume_db)

func _restore_menu_music() -> void:
	if MusicManager == null:
		return
	MusicManager.stop_pause_menu_music(chase_music_resume_fade_time)

func _stop_menu_music() -> void:
	if MusicManager == null:
		return
	MusicManager.stop_pause_menu_music(chase_music_resume_fade_time)
	MusicManager.clear_stack()
	MusicManager.stop_music(menu_music_fade_time)
	MusicManager.clear_chase_music_sources(menu_music_fade_time)
