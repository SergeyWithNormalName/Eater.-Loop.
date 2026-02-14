extends "res://levels/menu/menu_base.gd"

@export_group("Сцены")
## Сцена, которая запускается при новой игре.
@export var new_game_scene: PackedScene
## Звук сна при старте новой игры.
@export var new_game_sleep_sfx: AudioStream = preload("res://objects/interactable/bed/OutOfBed.wav")

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

@export_group("Дисклеймер")
@export_range(1.0, 60.0, 1.0) var disclaimer_auto_hide_time: float = 15.0
@export_range(0.1, 3.0, 0.05) var disclaimer_reveal_time: float = 1.05
@export_range(16, 42, 1) var disclaimer_body_font_size: int = 30
@export_range(12, 32, 1) var disclaimer_body_font_min_size: int = 20

@onready var _title_label: Label = $MainPanelCenter/MainPanel/VBox/Title
@onready var _new_game_button: Button = $MainPanelCenter/MainPanel/VBox/Buttons/NewGameButton
@onready var _continue_button: Button = $MainPanelCenter/MainPanel/VBox/Buttons/ContinueButton
@onready var _settings_button: Button = $MainPanelCenter/MainPanel/VBox/Buttons/SettingsButton
@onready var _credits_button: Button = $MainPanelCenter/MainPanel/VBox/Buttons/CreditsButton
@onready var _exit_button: Button = $MainPanelCenter/MainPanel/VBox/Buttons/ExitButton

@onready var _main_panel: Control = $MainPanelCenter/MainPanel
@onready var _settings_panel: Control = $SettingsPanelCenter/SettingsPanel
@onready var _credits_panel: Control = $CreditsPanelCenter/CreditsPanel
@onready var _credits_title: Label = $CreditsPanelCenter/CreditsPanel/VBox/Title
@onready var _credits_scroll: ScrollContainer = $CreditsPanelCenter/CreditsPanel/VBox/CreditsScroll
@onready var _credits_back: Button = $CreditsPanelCenter/CreditsPanel/VBox/BackButton

@onready var _difficulty_panel: Control = $DifficultyPanelCenter/DifficultyPanel
@onready var _difficulty_title: Label = $DifficultyPanelCenter/DifficultyPanel/VBox/Title
@onready var _difficulty_label: Label = $DifficultyPanelCenter/DifficultyPanel/VBox/Message
@onready var _difficulty_description: Label = $DifficultyPanelCenter/DifficultyPanel/VBox/DescriptionPanel/Description
@onready var _difficulty_simplified: Button = $DifficultyPanelCenter/DifficultyPanel/VBox/DifficultyButtons/SimplifiedButton
@onready var _difficulty_hardcore: Button = $DifficultyPanelCenter/DifficultyPanel/VBox/DifficultyButtons/HardcoreButton
@onready var _difficulty_back: Button = $DifficultyPanelCenter/DifficultyPanel/VBox/BottomRow/BackButton
@onready var _difficulty_start: Button = $DifficultyPanelCenter/DifficultyPanel/VBox/BottomRow/StartButton

@onready var _startup_blur_spoiler: ColorRect = $StartupBlurSpoiler
@onready var _startup_disclaimer: CenterContainer = $StartupDisclaimer
@onready var _startup_disclaimer_card: PanelContainer = $StartupDisclaimer/StartupCard
@onready var _startup_disclaimer_title: Label = $StartupDisclaimer/StartupCard/Margin/VBox/Title
@onready var _startup_disclaimer_subtitle: Label = $StartupDisclaimer/StartupCard/Margin/VBox/Subtitle
@onready var _startup_disclaimer_text: RichTextLabel = $StartupDisclaimer/StartupCard/Margin/VBox/TextPlate/TextMargin/DisclaimerText
@onready var _startup_disclaimer_timer: Timer = $StartupDisclaimerTimer

var _credits_active: bool = false
const PANEL_MAIN := "main"
const PANEL_SETTINGS := "settings"
const PANEL_CREDITS := "credits"
const PANEL_DIFFICULTY := "difficulty"
const DIFFICULTY_NONE := -1
const STARTUP_DISCLAIMER_META := "startup_disclaimer_shown_session"
const STARTUP_DISCLAIMER_STATE_PATH := "user://startup_state.cfg"
const STARTUP_DISCLAIMER_SECTION := "ui"
const STARTUP_DISCLAIMER_KEY := "disclaimer_seen"
const MENU_SPOILER_SHADER: Shader = preload("res://levels/menu/screen_spoiler_blur.gdshader")
const DIFFICULTY_DESCRIPTION_DEFAULT := "Выберите сложность, чтобы увидеть её описание."
const DIFFICULTY_DESCRIPTION_SIMPLIFIED := "В упрощённой сложности противники передвигаются медленнее, способы борьбы с ними более доступны, а цена ошибки — ниже."
const DIFFICULTY_DESCRIPTION_CANONICAL := "В канонической сложности противники представляют реальную угрозу, цена каждой ошибки высока, а игровые задачи окажутся менее простыми."
const STARTUP_DISCLAIMER_TEXT := """Данная игра является художественным произведением. Все события, персонажи, образы и ситуации являются вымышленными либо используются в художественной интерпретации. Любые совпадения с реальными лицами, событиями или обстоятельствами являются случайными.

Все графические материалы, анимации и визуальные элементы созданы с использованием технологий генеративного искусственного интеллекта либо иными законными способами. Музыкальные произведения и звуковые эффекты либо созданы автором игры, либо используются на основании лицензии CC0 (Creative Commons Zero) либо иных свободных лицензий, допускающих свободное использование.

Игра может содержать сцены психологического напряжения, тревожные визуальные и звуковые эффекты, скримеры, а также элементы, способные вызвать дискомфорт. Лицам с повышенной чувствительностью, сердечно-сосудистыми заболеваниями, эпилепсией или иными медицинскими противопоказаниями рекомендуется соблюдать осторожность.

Игра не содержит призывов к противоправным действиям, насилию, дискриминации либо иным формам противоправного поведения. Автор не пропагандирует и не одобряет какие-либо формы вредного или опасного поведения.

Использование игры осуществляется пользователем добровольно и на собственный риск. Автор не несёт ответственности за возможный физический, психологический или иной ущерб, возникший в результате использования игры."""

var _active_panel: String = PANEL_MAIN
var _selected_difficulty: int = DIFFICULTY_NONE
var _navigation_input_active: bool = false
var _startup_disclaimer_active: bool = false
var _startup_disclaimer_transitioning: bool = false
var _startup_blur_material: ShaderMaterial

func _ready() -> void:
	super._ready()
	apply_title_style(_title_label)
	apply_title_style(_credits_title)
	apply_title_style(_difficulty_title)
	_apply_menu_visual_style()
	_connect_buttons()
	_update_continue_state()
	_show_main()
	_play_menu_music()
	_startup_disclaimer_timer.timeout.connect(_on_startup_disclaimer_timeout)
	_setup_startup_disclaimer()

func _input(event: InputEvent) -> void:
	if _startup_disclaimer_active:
		if _is_disclaimer_skip_event(event):
			get_viewport().set_input_as_handled()
			_dismiss_startup_disclaimer()
		return
	_update_navigation_input_mode(event)

func _process(delta: float) -> void:
	if not _credits_active:
		return
	var max_scroll := _credits_scroll.get_v_scroll_bar().max_value
	_credits_scroll.scroll_vertical = min(_credits_scroll.scroll_vertical + credits_scroll_speed * delta, max_scroll)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_fit_startup_disclaimer_text")

func _unhandled_input(event: InputEvent) -> void:
	if _startup_disclaimer_active:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _credits_panel.visible:
			_hide_credits()
			get_viewport().set_input_as_handled()
			return
		if _settings_panel.visible:
			_hide_settings()
			get_viewport().set_input_as_handled()
			return
		if _difficulty_panel.visible:
			_hide_difficulty()
			get_viewport().set_input_as_handled()

func _connect_buttons() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_credits_back.pressed.connect(_hide_credits)
	_difficulty_simplified.pressed.connect(_on_difficulty_simplified_pressed)
	_difficulty_hardcore.pressed.connect(_on_difficulty_hardcore_pressed)
	_difficulty_start.pressed.connect(_on_difficulty_start_pressed)
	_difficulty_back.pressed.connect(_hide_difficulty)
	if _settings_panel.has_signal("closed"):
		_settings_panel.connect("closed", _hide_settings)

func _update_continue_state() -> void:
	var can_continue := GameState != null and GameState.has_active_run and GameState.last_scene_path != ""
	_continue_button.disabled = not can_continue

func _show_main() -> void:
	_active_panel = PANEL_MAIN
	_main_panel.visible = true
	_settings_panel.visible = false
	_credits_panel.visible = false
	_difficulty_panel.visible = false
	_credits_active = false
	_update_continue_state()
	_apply_navigation_focus_state()

func _on_new_game_pressed() -> void:
	_show_difficulty_selection()

func _on_continue_pressed() -> void:
	_start_continue()

func _on_settings_pressed() -> void:
	_active_panel = PANEL_SETTINGS
	_main_panel.visible = false
	_settings_panel.visible = true
	_credits_panel.visible = false
	_difficulty_panel.visible = false
	_apply_navigation_focus_state()

func _on_credits_pressed() -> void:
	_active_panel = PANEL_CREDITS
	_main_panel.visible = false
	_settings_panel.visible = false
	_difficulty_panel.visible = false
	_credits_panel.visible = true
	_credits_scroll.scroll_vertical = 0
	_credits_active = true
	_apply_navigation_focus_state()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _show_difficulty_selection() -> void:
	_active_panel = PANEL_DIFFICULTY
	_main_panel.visible = false
	_settings_panel.visible = false
	_credits_panel.visible = false
	_credits_active = false
	_difficulty_panel.visible = true
	_difficulty_label.text = "Выберите сложность"
	_reset_difficulty_selection()
	_apply_navigation_focus_state()

func _start_new_game(difficulty: int) -> void:
	if new_game_scene == null:
		push_warning("MainMenu: не назначена сцена для новой игры.")
		return
	if GameState:
		GameState.reset_run()
		if GameState.has_method("set_difficulty"):
			GameState.set_difficulty(difficulty)
		GameState.set_current_scene_path(new_game_scene.resource_path)
		GameState.pending_sleep_spawn = true
	_stop_menu_music()
	await UIMessage.change_scene_with_fade_delay(new_game_scene, 0.4, _get_sleep_sfx_delay())

func _get_sleep_sfx_delay() -> float:
	if new_game_sleep_sfx == null:
		return 0.0
	var length := new_game_sleep_sfx.get_length()
	if length <= 0.0:
		return 1.0
	return length

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

func _hide_difficulty() -> void:
	_show_main()

func _on_difficulty_simplified_pressed() -> void:
	_select_difficulty(GameState.Difficulty.SIMPLIFIED)

func _on_difficulty_hardcore_pressed() -> void:
	_select_difficulty(GameState.Difficulty.HARDCORE)

func _on_difficulty_start_pressed() -> void:
	if _selected_difficulty == DIFFICULTY_NONE:
		return
	_start_new_game(_selected_difficulty)

func _hide_settings() -> void:
	_show_main()

func _hide_credits() -> void:
	_credits_active = false
	_show_main()

func _reset_difficulty_selection() -> void:
	_selected_difficulty = DIFFICULTY_NONE
	_refresh_difficulty_selection()

func _select_difficulty(difficulty: int) -> void:
	_selected_difficulty = difficulty
	_refresh_difficulty_selection()

func _refresh_difficulty_selection() -> void:
	_difficulty_simplified.set_pressed_no_signal(_selected_difficulty == GameState.Difficulty.SIMPLIFIED)
	_difficulty_hardcore.set_pressed_no_signal(_selected_difficulty == GameState.Difficulty.HARDCORE)
	_difficulty_start.disabled = _selected_difficulty == DIFFICULTY_NONE
	match _selected_difficulty:
		GameState.Difficulty.SIMPLIFIED:
			_difficulty_description.text = DIFFICULTY_DESCRIPTION_SIMPLIFIED
		GameState.Difficulty.HARDCORE:
			_difficulty_description.text = DIFFICULTY_DESCRIPTION_CANONICAL
		_:
			_difficulty_description.text = DIFFICULTY_DESCRIPTION_DEFAULT

func _update_navigation_input_mode(event: InputEvent) -> void:
	if event == null:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_navigation_input_active(false)
		return
	if _is_navigation_activation_event(event):
		var was_active := _navigation_input_active
		_set_navigation_input_active(true)
		if not was_active:
			get_viewport().set_input_as_handled()

func _is_navigation_activation_event(event: InputEvent) -> bool:
	if event == null or event.is_echo():
		return false
	if event is InputEventKey:
		return event.is_action_pressed("ui_up") \
			or event.is_action_pressed("ui_down") \
			or event.is_action_pressed("ui_left") \
			or event.is_action_pressed("ui_right")
	if event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		return joy_button.pressed
	if event is InputEventJoypadMotion:
		var joy_motion := event as InputEventJoypadMotion
		return absf(joy_motion.axis_value) >= 0.5
	return false

func _set_navigation_input_active(active: bool) -> void:
	if _navigation_input_active == active:
		return
	_navigation_input_active = active
	_apply_navigation_focus_state()

func _apply_navigation_focus_state() -> void:
	if _navigation_input_active:
		_focus_active_panel_default()
		return
	_release_gui_focus()

func _focus_active_panel_default() -> void:
	match _active_panel:
		PANEL_SETTINGS:
			_focus_settings_default()
		PANEL_CREDITS:
			_grab_focus_if_visible(_credits_back)
		PANEL_DIFFICULTY:
			_grab_focus_if_visible(_difficulty_simplified)
		_:
			_grab_focus_if_visible(_new_game_button)

func _focus_settings_default() -> void:
	if not _settings_panel.visible:
		return
	if _settings_panel.has_method("focus_default"):
		_settings_panel.call("focus_default")

func _grab_focus_if_visible(control: Control) -> void:
	if control == null:
		return
	if not control.is_visible_in_tree():
		return
	control.grab_focus()

func _release_gui_focus() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return
	focus_owner.release_focus()

func _apply_menu_visual_style() -> void:
	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color(0.04, 0.07, 0.12, 0.45)
	button_normal.border_width_left = 1
	button_normal.border_width_top = 1
	button_normal.border_width_right = 1
	button_normal.border_width_bottom = 1
	button_normal.border_color = Color(0.62, 0.75, 1.0, 0.24)
	button_normal.corner_radius_top_left = 10
	button_normal.corner_radius_top_right = 10
	button_normal.corner_radius_bottom_right = 10
	button_normal.corner_radius_bottom_left = 10
	button_normal.content_margin_left = 24.0
	button_normal.content_margin_top = 12.0
	button_normal.content_margin_right = 24.0
	button_normal.content_margin_bottom = 14.0

	var button_hover := button_normal.duplicate() as StyleBoxFlat
	button_hover.bg_color = Color(0.08, 0.12, 0.2, 0.7)
	button_hover.border_color = Color(0.78, 0.9, 1.0, 0.65)

	var button_focus := button_normal.duplicate() as StyleBoxFlat
	button_focus.bg_color = Color(0.07, 0.11, 0.19, 0.68)
	button_focus.border_color = Color(0.9, 0.97, 1.0, 0.92)
	button_focus.shadow_color = Color(0.38, 0.62, 1.0, 0.3)
	button_focus.shadow_size = 10

	var button_pressed := button_normal.duplicate() as StyleBoxFlat
	button_pressed.bg_color = Color(0.09, 0.16, 0.25, 0.82)
	button_pressed.border_color = Color(0.9, 0.97, 1.0, 0.95)

	var button_disabled := button_normal.duplicate() as StyleBoxFlat
	button_disabled.bg_color = Color(0.04, 0.07, 0.11, 0.18)
	button_disabled.border_color = Color(0.56, 0.67, 0.85, 0.12)

	var buttons := find_children("*", "Button", true, false)
	for node in buttons:
		var button := node as Button
		if button == null:
			continue
		if not button.is_in_group("menu_button"):
			continue
		button.custom_minimum_size = Vector2(0.0, 72.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_stylebox_override("normal", button_normal)
		button.add_theme_stylebox_override("hover", button_hover)
		button.add_theme_stylebox_override("focus", button_focus)
		button.add_theme_stylebox_override("pressed", button_pressed)
		button.add_theme_stylebox_override("disabled", button_disabled)
		button.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.96))
		button.add_theme_color_override("font_hover_color", Color(0.98, 0.99, 1.0, 1.0))
		button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.95, 0.99, 1.0, 1.0))
		button.add_theme_color_override("font_disabled_color", Color(0.55, 0.6, 0.71, 0.85))

	_difficulty_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.98, 0.82))
	_difficulty_description.add_theme_color_override("font_color", Color(0.91, 0.95, 1.0, 0.95))
	_difficulty_description.add_theme_font_size_override("font_size", body_font_size - 2)
	_difficulty_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _play_menu_music() -> void:
	if MusicManager == null or menu_music == null:
		return
	MusicManager.clear_stack()
	MusicManager.play_menu_music(menu_music, menu_music_fade_time, menu_music_volume_db)

func _stop_menu_music() -> void:
	if MusicManager == null:
		return
	MusicManager.stop_music(menu_music_fade_time)

func _setup_startup_disclaimer() -> void:
	_startup_disclaimer_text.text = STARTUP_DISCLAIMER_TEXT
	_apply_startup_disclaimer_style()
	_startup_blur_spoiler.visible = false
	_startup_disclaimer.visible = false
	call_deferred("_fit_startup_disclaimer_text")
	if not _should_show_startup_disclaimer():
		return
	_activate_startup_disclaimer()

func _should_show_startup_disclaimer() -> bool:
	if GameState == null:
		var unseen_without_gamestate := not _is_startup_disclaimer_seen_persisted()
		if unseen_without_gamestate:
			_mark_startup_disclaimer_seen_persisted()
		return unseen_without_gamestate
	if GameState.has_meta(STARTUP_DISCLAIMER_META):
		return false
	if _is_startup_disclaimer_seen_persisted():
		GameState.set_meta(STARTUP_DISCLAIMER_META, true)
		return false
	GameState.set_meta(STARTUP_DISCLAIMER_META, true)
	_mark_startup_disclaimer_seen_persisted()
	return true

func _activate_startup_disclaimer() -> void:
	_startup_disclaimer_active = true
	_startup_disclaimer_transitioning = false
	_startup_disclaimer.visible = true
	_startup_disclaimer.modulate = Color(1, 1, 1, 1)
	_startup_disclaimer.mouse_filter = Control.MOUSE_FILTER_STOP
	_startup_disclaimer_card.scale = Vector2.ONE

	_startup_blur_spoiler.visible = true
	_startup_blur_spoiler.modulate = Color(1, 1, 1, 1)
	_startup_blur_spoiler.mouse_filter = Control.MOUSE_FILTER_STOP
	_startup_blur_material = ShaderMaterial.new()
	_startup_blur_material.shader = MENU_SPOILER_SHADER
	_startup_blur_material.set_shader_parameter("blur_strength", 1.0)
	_startup_blur_material.set_shader_parameter("blur_lod", 2.8)
	_startup_blur_material.set_shader_parameter("tint_strength", 0.24)
	_startup_blur_spoiler.material = _startup_blur_material

	_startup_disclaimer_timer.start(disclaimer_auto_hide_time)

func _dismiss_startup_disclaimer() -> void:
	if not _startup_disclaimer_active or _startup_disclaimer_transitioning:
		return
	_startup_disclaimer_transitioning = true

	var reveal_time: float = maxf(0.1, disclaimer_reveal_time)
	var text_fade_time: float = minf(reveal_time * 0.75, 0.7)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	if _startup_blur_material != null:
		tween.tween_method(
			func(value: float): _startup_blur_material.set_shader_parameter("blur_strength", value),
			1.0,
			0.0,
			reveal_time
		)
		tween.tween_method(
			func(value: float): _startup_blur_material.set_shader_parameter("tint_strength", value),
			0.24,
			0.0,
			reveal_time
		)
	tween.tween_property(_startup_blur_spoiler, "modulate:a", 0.0, reveal_time)
	tween.tween_property(_startup_disclaimer, "modulate:a", 0.0, text_fade_time)
	tween.tween_property(_startup_disclaimer_card, "scale", Vector2(1.01, 1.01), text_fade_time)
	await tween.finished

	_startup_disclaimer_active = false
	_startup_disclaimer_transitioning = false
	_startup_disclaimer_timer.stop()
	_startup_disclaimer.visible = false
	_startup_blur_spoiler.visible = false
	_startup_disclaimer.modulate = Color(1, 1, 1, 1)
	_startup_blur_spoiler.modulate = Color(1, 1, 1, 1)
	_startup_disclaimer_card.scale = Vector2.ONE
	_startup_blur_spoiler.material = null
	_startup_blur_material = null

func _on_startup_disclaimer_timeout() -> void:
	if not _startup_disclaimer_active or _startup_disclaimer_transitioning:
		return
	_dismiss_startup_disclaimer()

func _is_disclaimer_skip_event(event: InputEvent) -> bool:
	if event == null or event.is_echo():
		return false
	if event is InputEventMouseMotion:
		return false
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= 0.55
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _apply_startup_disclaimer_style() -> void:
	var base_font := SystemFont.new()
	base_font.font_names = PackedStringArray([
		"Segoe UI",
		"Noto Sans",
		"SF Pro Text",
		"Roboto",
		"Arial",
		"Helvetica",
		"Liberation Sans",
		"DejaVu Sans",
	])

	var ui_font := FontVariation.new()
	ui_font.base_font = base_font
	ui_font.spacing_glyph = 0

	_startup_disclaimer_title.add_theme_font_override("font", ui_font)
	_startup_disclaimer_title.add_theme_font_size_override("font_size", 54)
	_startup_disclaimer_title.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 0.98))

	_startup_disclaimer_subtitle.add_theme_font_override("font", ui_font)
	_startup_disclaimer_subtitle.add_theme_font_size_override("font_size", 21)
	_startup_disclaimer_subtitle.add_theme_color_override("font_color", Color(0.77, 0.87, 1.0, 0.9))

	_startup_disclaimer_text.add_theme_font_override("normal_font", ui_font)
	_startup_disclaimer_text.add_theme_font_size_override("normal_font_size", disclaimer_body_font_size)
	_startup_disclaimer_text.add_theme_color_override("default_color", Color(0.94, 0.96, 1.0, 0.95))

func _fit_startup_disclaimer_text() -> void:
	if _startup_disclaimer_text == null:
		return
	if _startup_disclaimer_text.size.x <= 0.0:
		return
	var available_height: float = _startup_disclaimer_text.size.y
	if available_height <= 0.0:
		return
	var selected_size: int = disclaimer_body_font_min_size
	var size: int = disclaimer_body_font_size
	while size >= disclaimer_body_font_min_size:
		_startup_disclaimer_text.add_theme_font_size_override("normal_font_size", size)
		var content_height: float = _startup_disclaimer_text.get_content_height()
		if content_height <= available_height:
			selected_size = size
			break
		size -= 1
	_startup_disclaimer_text.add_theme_font_size_override("normal_font_size", selected_size)
	_startup_disclaimer_text.scroll_to_line(0)

func _is_startup_disclaimer_seen_persisted() -> bool:
	var config := ConfigFile.new()
	if config.load(STARTUP_DISCLAIMER_STATE_PATH) != OK:
		return false
	return bool(config.get_value(STARTUP_DISCLAIMER_SECTION, STARTUP_DISCLAIMER_KEY, false))

func _mark_startup_disclaimer_seen_persisted() -> void:
	var config := ConfigFile.new()
	config.load(STARTUP_DISCLAIMER_STATE_PATH)
	config.set_value(STARTUP_DISCLAIMER_SECTION, STARTUP_DISCLAIMER_KEY, true)
	config.save(STARTUP_DISCLAIMER_STATE_PATH)
