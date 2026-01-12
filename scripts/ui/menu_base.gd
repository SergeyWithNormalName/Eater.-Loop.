extends Control

@export_group("Шрифт")
## Размер шрифта для заголовков.
@export var title_font_size: int = 96
## Размер шрифта для кнопок.
@export var button_font_size: int = 52
## Размер шрифта для текста/описаний.
@export var body_font_size: int = 32

@export_group("SFX")
## Звук наведения.
@export var hover_sfx: AudioStream
## Звук нажатия.
@export var click_sfx: AudioStream
## Громкость SFX (дБ).
@export_range(-40.0, 6.0, 0.1) var sfx_volume_db: float = -6.0

@export_group("Визуальный отклик")
## Масштаб кнопки при фокусе/наведении.
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.05
## Цвет кнопки при фокусе/наведении.
@export var hover_tint: Color = Color(1.0, 0.95, 0.9)

@onready var _sfx_player: AudioStreamPlayer = _resolve_sfx_player()

func _ready() -> void:
	_apply_theme()
	_wire_buttons()

func _apply_theme() -> void:
	var regular_font := load("res://fonts/AmaticSC-Regular.ttf")
	var bold_font := load("res://fonts/AmaticSC-Bold.ttf")
	if not regular_font:
		return

	var theme := Theme.new()
	var body_font := FontVariation.new()
	body_font.base_font = regular_font
	body_font.spacing_glyph = 3

	var title_font := FontVariation.new()
	title_font.base_font = bold_font if bold_font else regular_font
	title_font.spacing_glyph = 4

	theme.set_font("font", "Label", body_font)
	theme.set_font_size("font_size", "Label", body_font_size)

	theme.set_font("font", "Button", body_font)
	theme.set_font_size("font_size", "Button", button_font_size)

	set_theme(theme)
	set_meta("menu_title_font", title_font)

func apply_title_style(label: Label) -> void:
	if label == null:
		return
	var title_font: FontVariation = get_meta("menu_title_font") as FontVariation
	if title_font:
		label.add_theme_font_override("font", title_font)
	label.add_theme_font_size_override("font_size", title_font_size)

func _wire_buttons() -> void:
	var buttons := get_tree().get_nodes_in_group("menu_button")
	for node in buttons:
		var button := node as Button
		if button == null:
			continue
		button.focus_mode = Control.FOCUS_ALL
		button.pivot_offset = button.size * 0.5
		button.resized.connect(func(): button.pivot_offset = button.size * 0.5)
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.focus_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))
		button.focus_exited.connect(_on_button_unhover.bind(button))
		button.pressed.connect(_on_button_pressed.bind(button))

func _on_button_hover(button: Button) -> void:
	if button.disabled:
		return
	_play_sfx(hover_sfx)
	_tween_button(button, hover_scale, hover_tint)

func _on_button_unhover(button: Button) -> void:
	_tween_button(button, 1.0, Color(1, 1, 1, 1))

func _on_button_pressed(_button: Button) -> void:
	_play_sfx(click_sfx)

func _tween_button(button: Button, target_scale: float, target_tint: Color) -> void:
	var tween: Tween = button.get_meta("hover_tween") as Tween
	if tween and tween.is_running():
		tween.kill()
	var new_tween := button.create_tween()
	button.set_meta("hover_tween", new_tween)
	new_tween.set_parallel(true)
	new_tween.tween_property(button, "scale", Vector2(target_scale, target_scale), 0.12)
	new_tween.tween_property(button, "modulate", target_tint, 0.12)
	new_tween.set_parallel(false)

func _play_sfx(stream: AudioStream) -> void:
	if _sfx_player == null or stream == null:
		return
	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.volume_db = sfx_volume_db
	_sfx_player.play()

func _resolve_sfx_player() -> AudioStreamPlayer:
	if has_node("SfxPlayer"):
		return get_node("SfxPlayer") as AudioStreamPlayer
	return null
