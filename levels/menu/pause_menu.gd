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

const EXIT_WARNING := "Несохранённые данные будут потеряны. Вы сможете продолжить только с начала текущего цикла."

@onready var _title_label: Label = $MainPanel/VBox/Title
@onready var _resume_button: Button = $MainPanel/VBox/Buttons/ResumeButton
@onready var _settings_button: Button = $MainPanel/VBox/Buttons/SettingsButton
@onready var _exit_menu_button: Button = $MainPanel/VBox/Buttons/ExitMenuButton
@onready var _exit_game_button: Button = $MainPanel/VBox/Buttons/ExitGameButton

@onready var _main_panel: Control = $MainPanel
@onready var _settings_panel: Control = $SettingsPanel

@onready var _confirm_panel: Control = $ConfirmPanel
@onready var _confirm_label: Label = $ConfirmPanel/VBox/Message
@onready var _confirm_yes: Button = $ConfirmPanel/VBox/Buttons/YesButton
@onready var _confirm_no: Button = $ConfirmPanel/VBox/Buttons/NoButton

var _confirm_action: Callable
const PANEL_MAIN := "main"
const PANEL_SETTINGS := "settings"
var _active_panel: String = PANEL_MAIN
var _panel_before_confirm: String = PANEL_MAIN

func _ready() -> void:
	super._ready()
	apply_title_style(_title_label)
	_connect_buttons()
	_show_main()

func _unhandled_input(event: InputEvent) -> void:
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
