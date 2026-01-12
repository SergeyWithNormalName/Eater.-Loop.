extends "res://scripts/ui/menu_base.gd"

@export_group("Сцены")
## Сцена, которая запускается при новой игре.
@export var new_game_scene: PackedScene

@export_group("Музыка")
## Музыка главного меню.
@export var menu_music: AudioStream
## Громкость музыки меню (дБ).
@export_range(-80.0, 6.0, 0.1) var menu_music_volume_db: float = -12.0
## Длительность плавного перехода (сек).
@export_range(0.0, 10.0, 0.1) var menu_music_fade_time: float = 1.2

@export_group("Титры")
## Скорость прокрутки титров.
@export_range(5.0, 200.0, 1.0) var credits_scroll_speed: float = 40.0

@onready var _title_label: Label = $MainPanel/VBox/Title
@onready var _new_game_button: Button = $MainPanel/VBox/Buttons/NewGameButton
@onready var _continue_button: Button = $MainPanel/VBox/Buttons/ContinueButton
@onready var _settings_button: Button = $MainPanel/VBox/Buttons/SettingsButton
@onready var _credits_button: Button = $MainPanel/VBox/Buttons/CreditsButton
@onready var _exit_button: Button = $MainPanel/VBox/Buttons/ExitButton

@onready var _main_panel: Control = $MainPanel
@onready var _settings_panel: Control = $SettingsPanel
@onready var _credits_panel: Control = $CreditsPanel
@onready var _credits_title: Label = $CreditsPanel/VBox/Title
@onready var _credits_scroll: ScrollContainer = $CreditsPanel/VBox/CreditsScroll
@onready var _credits_back: Button = $CreditsPanel/VBox/BackButton

@onready var _confirm_panel: Control = $ConfirmPanel
@onready var _confirm_label: Label = $ConfirmPanel/VBox/Message
@onready var _confirm_yes: Button = $ConfirmPanel/VBox/Buttons/YesButton
@onready var _confirm_no: Button = $ConfirmPanel/VBox/Buttons/NoButton

var _confirm_action: Callable
var _credits_active: bool = false

func _ready() -> void:
	super._ready()
	apply_title_style(_title_label)
	apply_title_style(_credits_title)
	_connect_buttons()
	_update_continue_state()
	_show_main()
	_play_menu_music()

func _process(delta: float) -> void:
	if not _credits_active:
		return
	var max_scroll := _credits_scroll.get_v_scroll_bar().max_value
	_credits_scroll.scroll_vertical = min(_credits_scroll.scroll_vertical + credits_scroll_speed * delta, max_scroll)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _confirm_panel.visible:
			_hide_confirm()
			get_viewport().set_input_as_handled()
			return
		if _credits_panel.visible:
			_hide_credits()
			get_viewport().set_input_as_handled()
			return
		if _settings_panel.visible:
			_hide_settings()
			get_viewport().set_input_as_handled()

func _connect_buttons() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_credits_back.pressed.connect(_hide_credits)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_hide_confirm)
	if _settings_panel.has_signal("closed"):
		_settings_panel.connect("closed", _hide_settings)

func _update_continue_state() -> void:
	var can_continue := GameState != null and GameState.has_active_run and GameState.last_scene_path != ""
	_continue_button.disabled = not can_continue

func _show_main() -> void:
	_main_panel.visible = true
	_settings_panel.visible = false
	_credits_panel.visible = false
	_confirm_panel.visible = false
	_credits_active = false
	_update_continue_state()
	_new_game_button.grab_focus()

func _on_new_game_pressed() -> void:
	_show_confirm("Точно начать новую игру?", _start_new_game)

func _on_continue_pressed() -> void:
	_start_continue()

func _on_settings_pressed() -> void:
	_main_panel.visible = false
	_settings_panel.visible = true
	_credits_panel.visible = false
	_confirm_panel.visible = false
	if _settings_panel.has_method("focus_default"):
		_settings_panel.call("focus_default")

func _on_credits_pressed() -> void:
	_main_panel.visible = false
	_settings_panel.visible = false
	_confirm_panel.visible = false
	_credits_panel.visible = true
	_credits_scroll.scroll_vertical = 0
	_credits_active = true
	_credits_back.grab_focus()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _start_new_game() -> void:
	if new_game_scene == null:
		push_warning("MainMenu: не назначена сцена для новой игры.")
		return
	if GameState:
		GameState.reset_run()
		GameState.set_current_scene_path(new_game_scene.resource_path)
	_stop_menu_music()
	await UIMessage.change_scene_with_fade(new_game_scene)

func _start_continue() -> void:
	if GameState == null:
		return
	if GameState.last_scene_path == "":
		return
	var scene := load(GameState.last_scene_path) as PackedScene
	if scene == null:
		push_warning("MainMenu: не удалось загрузить сцену продолжения: %s" % GameState.last_scene_path)
		return
	_stop_menu_music()
	await UIMessage.change_scene_with_fade(scene)

func _show_confirm(message: String, action: Callable) -> void:
	_confirm_label.text = message
	_confirm_action = action
	_confirm_panel.visible = true
	_confirm_yes.grab_focus()

func _hide_confirm() -> void:
	_confirm_panel.visible = false
	_confirm_action = Callable()
	_new_game_button.grab_focus()

func _on_confirm_yes() -> void:
	_confirm_panel.visible = false
	if _confirm_action.is_valid():
		_confirm_action.call()

func _hide_settings() -> void:
	_show_main()

func _hide_credits() -> void:
	_credits_active = false
	_show_main()

func _play_menu_music() -> void:
	if MusicManager == null or menu_music == null:
		return
	MusicManager.clear_stack()
	MusicManager.play_music(menu_music, menu_music_fade_time, menu_music_volume_db)

func _stop_menu_music() -> void:
	if MusicManager == null:
		return
	MusicManager.stop_music(menu_music_fade_time)
