extends Control

@export_group("Шрифт")
## Размер шрифта для заголовков.
@export var title_font_size: int = 96
## Размер шрифта для кнопок.
@export var button_font_size: int = 52
## Размер шрифта для текста/описаний.
@export var body_font_size: int = 32

@export_group("Sounds")
## Звук наведения.
@export var hover_sfx: AudioStream
## Звук нажатия.
@export var click_sfx: AudioStream
## Громкость звуков (дБ).
## Громкость звука наведения (дБ).
@export_range(-40.0, 6.0, 0.1) var hover_sfx_volume_db: float = -10.0
## Громкость звука нажатия (дБ).
@export_range(-40.0, 6.0, 0.1) var click_sfx_volume_db: float = -10.0

@export_group("Визуальный отклик")
## Масштаб кнопки при фокусе/наведении.
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.05
## Цвет кнопки при фокусе/наведении.
@export var hover_tint: Color = Color(1.0, 0.95, 0.9)

@onready var _sfx_player: AudioStreamPlayer = _resolve_sfx_player()

func _ready() -> void:
	_apply_theme()
	_wire_buttons()
	_update_cursor_request()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_update_cursor_request()

func _exit_tree() -> void:
	_release_cursor_request()

func _apply_theme() -> void:
	var regular_font := load("res://global/fonts/AmaticSC-Regular.ttf")
	var bold_font := load("res://global/fonts/AmaticSC-Bold.ttf")
	if not regular_font:
		return

	var menu_theme := Theme.new()
	var body_font := FontVariation.new()
	body_font.base_font = regular_font
	body_font.spacing_glyph = 3

	var title_font := FontVariation.new()
	title_font.base_font = bold_font if bold_font else regular_font
	title_font.spacing_glyph = 4

	menu_theme.set_font("font", "Label", body_font)
	menu_theme.set_font_size("font_size", "Label", body_font_size)

	menu_theme.set_font("font", "Button", body_font)
	menu_theme.set_font_size("font_size", "Button", button_font_size)

	set_theme(menu_theme)
	set_meta("menu_title_font", title_font)

func apply_title_style(label: Label) -> void:
	if label == null:
		return
	var title_font: FontVariation = get_meta("menu_title_font") as FontVariation
	if title_font:
		label.add_theme_font_override("font", title_font)
	label.add_theme_font_size_override("font_size", title_font_size)

func _wire_buttons() -> void:
	var buttons := find_children("*", "Button", true, false)
	for node in buttons:
		var button := node as Button
		if button == null:
			continue
		if not button.is_in_group("menu_button"):
			continue
		button.focus_mode = Control.FOCUS_ALL
		button.pivot_offset = button.size * 0.5
		button.resized.connect(func(): button.pivot_offset = button.size * 0.5)
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.focus_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))
		button.focus_exited.connect(_on_button_unhover.bind(button))
		_connect_button_press_sfx(button)

	var all_buttons := find_children("*", "BaseButton", true, false)
	for node in all_buttons:
		var button := node as BaseButton
		if button == null:
			continue
		_connect_button_press_sfx(button)

func _on_button_hover(button: Button) -> void:
	if button.disabled:
		return
	_play_sfx(hover_sfx, hover_sfx_volume_db)
	_tween_button(button, hover_scale, hover_tint)

func _on_button_unhover(button: Button) -> void:
	_tween_button(button, 1.0, Color(1, 1, 1, 1))

func _on_button_pressed(_button: BaseButton) -> void:
	_play_sfx(click_sfx, click_sfx_volume_db)

func _connect_button_press_sfx(button: BaseButton) -> void:
	if button.has_meta("menu_press_sfx_connected"):
		return
	button.pressed.connect(_on_button_pressed.bind(button))
	button.set_meta("menu_press_sfx_connected", true)

func _tween_button(button: Button, target_scale: float, target_tint: Color) -> void:
	var tween: Tween = null
	if button.has_meta("hover_tween"):
		tween = button.get_meta("hover_tween") as Tween
	if tween and tween.is_running():
		tween.kill()
	var new_tween := button.create_tween()
	button.set_meta("hover_tween", new_tween)
	new_tween.set_parallel(true)
	new_tween.tween_property(button, "scale", Vector2(target_scale, target_scale), 0.12)
	new_tween.tween_property(button, "modulate", target_tint, 0.12)
	new_tween.set_parallel(false)

func _play_sfx(stream: AudioStream, volume_db: float) -> void:
	if _sfx_player == null or stream == null:
		return
	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.play()

func _resolve_sfx_player() -> AudioStreamPlayer:
	if has_node("SfxPlayer"):
		return get_node("SfxPlayer") as AudioStreamPlayer
	return null

func _update_cursor_request() -> void:
	if CursorManager == null:
		return
	if is_visible_in_tree():
		CursorManager.request_visible(self)
	else:
		CursorManager.release_visible(self)

func _release_cursor_request() -> void:
	if CursorManager == null:
		return
	CursorManager.release_visible(self)
