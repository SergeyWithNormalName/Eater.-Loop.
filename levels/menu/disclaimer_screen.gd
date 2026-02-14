extends Control

@export_group("Сцены")
@export var main_menu_scene: PackedScene = preload("res://levels/menu/main_menu.tscn")

@export_group("Анимация")
@export_range(0.1, 3.0, 0.05) var intro_duration: float = 0.6
@export_range(0.1, 3.0, 0.05) var outro_duration: float = 0.35
@export_range(5.0, 60.0, 1.0) var auto_advance_delay: float = 15.0

@export_group("Макет")
@export var panel_viewport_ratio: Vector2 = Vector2(0.9, 0.9)
@export var panel_min_size: Vector2 = Vector2(660.0, 480.0)
@export var panel_max_size: Vector2 = Vector2(1600.0, 980.0)
@export_range(16, 42, 1) var body_font_size: int = 30
@export_range(12, 32, 1) var body_font_min_size: int = 20

const MENU_TRANSITION_META := "menu_intro_from_disclaimer"
const DISCLAIMER_TEXT := """Данная игра является художественным произведением. Все события, персонажи, образы и ситуации являются вымышленными либо используются в художественной интерпретации. Любые совпадения с реальными лицами, событиями или обстоятельствами являются случайными.

Все графические материалы, анимации и визуальные элементы созданы с использованием технологий генеративного искусственного интеллекта либо иными законными способами. Музыкальные произведения и звуковые эффекты либо созданы автором игры, либо используются на основании лицензии CC0 (Creative Commons Zero) либо иных свободных лицензий, допускающих свободное использование.

Игра может содержать сцены психологического напряжения, тревожные визуальные и звуковые эффекты, скримеры, а также элементы, способные вызвать дискомфорт. Лицам с повышенной чувствительностью, сердечно-сосудистыми заболеваниями, эпилепсией или иными медицинскими противопоказаниями рекомендуется соблюдать осторожность.

Игра не содержит призывов к противоправным действиям, насилию, дискриминации либо иным формам противоправного поведения. Автор не пропагандирует и не одобряет какие-либо формы вредного или опасного поведения.

Использование игры осуществляется пользователем добровольно и на собственный риск. Автор не несёт ответственности за возможный физический, психологический или иной ущерб, возникший в результате использования игры."""

var _is_transitioning: bool = false
var _intro_finished: bool = false
var _content_base_y: float = 0.0

@onready var _backdrop_tint: ColorRect = $BackdropTint
@onready var _content: PanelContainer = $CenterContainer/Content
@onready var _title_label: Label = $CenterContainer/Content/Margin/VBox/Title
@onready var _subtitle_label: Label = $CenterContainer/Content/Margin/VBox/Subtitle
@onready var _disclaimer_text: RichTextLabel = $CenterContainer/Content/Margin/VBox/TextPlate/TextMargin/DisclaimerText

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_readable_font()
	_disclaimer_text.text = DISCLAIMER_TEXT
	_update_layout()
	_prepare_intro_state()
	await get_tree().process_frame
	_fit_disclaimer_text_to_height()
	await _play_intro_animation()
	_intro_finished = true
	_run_auto_advance()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _unhandled_input(event: InputEvent) -> void:
	if not _intro_finished or _is_transitioning:
		return
	if _is_skip_input(event):
		get_viewport().set_input_as_handled()
		_advance_to_main_menu()

func _apply_readable_font() -> void:
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

	_title_label.add_theme_font_override("font", ui_font)
	_title_label.add_theme_font_size_override("font_size", 54)
	_title_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 0.98))

	_subtitle_label.add_theme_font_override("font", ui_font)
	_subtitle_label.add_theme_font_size_override("font_size", 21)
	_subtitle_label.add_theme_color_override("font_color", Color(0.77, 0.87, 1.0, 0.9))

	_disclaimer_text.add_theme_font_override("normal_font", ui_font)
	_disclaimer_text.add_theme_font_size_override("normal_font_size", body_font_size)
	_disclaimer_text.add_theme_color_override("default_color", Color(0.94, 0.96, 1.0, 0.95))

func _update_layout() -> void:
	if _content == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var target_size := viewport_size * panel_viewport_ratio
	target_size.x = clampf(target_size.x, panel_min_size.x, panel_max_size.x)
	target_size.y = clampf(target_size.y, panel_min_size.y, panel_max_size.y)
	_content.custom_minimum_size = target_size
	_content.size = target_size
	_content.pivot_offset = target_size * 0.5
	_content_base_y = _content.position.y
	if _intro_finished and not _is_transitioning:
		_content.position.y = _content_base_y
	call_deferred("_fit_disclaimer_text_to_height")

func _prepare_intro_state() -> void:
	_backdrop_tint.modulate.a = 0.0
	_content.modulate.a = 0.0
	_content.scale = Vector2(0.975, 0.975)
	_content.position.y = _content_base_y + 20.0

func _play_intro_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_backdrop_tint, "modulate:a", 1.0, intro_duration)
	tween.tween_property(_content, "modulate:a", 1.0, intro_duration)
	tween.tween_property(_content, "scale", Vector2.ONE, intro_duration)
	tween.tween_property(_content, "position:y", _content_base_y, intro_duration)
	tween.set_parallel(false)
	await tween.finished

func _play_outro_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_content, "modulate:a", 0.0, outro_duration)
	tween.tween_property(_content, "scale", Vector2(1.03, 1.03), outro_duration)
	tween.tween_property(_content, "position:y", _content_base_y - 12.0, outro_duration)
	tween.tween_property(_backdrop_tint, "modulate:a", 0.56, outro_duration)
	tween.set_parallel(false)
	await tween.finished

func _begin_transition() -> bool:
	if _is_transitioning or not _intro_finished:
		return false
	_is_transitioning = true
	return true

func _advance_to_main_menu() -> void:
	if not _begin_transition():
		return
	await _play_outro_animation()
	if main_menu_scene == null:
		push_warning("DisclaimerScreen: не назначена сцена главного меню.")
		_is_transitioning = false
		return
	if GameState:
		GameState.set_meta(MENU_TRANSITION_META, true)
	get_tree().change_scene_to_packed(main_menu_scene)

func _is_skip_input(event: InputEvent) -> bool:
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
		return absf((event as InputEventJoypadMotion).axis_value) >= 0.6
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _fit_disclaimer_text_to_height() -> void:
	if _disclaimer_text == null:
		return
	if _disclaimer_text.size.x <= 0.0:
		return
	var available_height: float = _disclaimer_text.size.y
	if available_height <= 0.0:
		return
	var selected_size: int = body_font_min_size
	var size: int = body_font_size
	while size >= body_font_min_size:
		_disclaimer_text.add_theme_font_size_override("normal_font_size", size)
		var content_height: float = _disclaimer_text.get_content_height()
		if content_height <= available_height:
			selected_size = size
			break
		size -= 1
	_disclaimer_text.add_theme_font_size_override("normal_font_size", selected_size)
	_disclaimer_text.scroll_to_line(0)

func _run_auto_advance() -> void:
	_wait_and_auto_advance()

func _wait_and_auto_advance() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(auto_advance_delay, true)
	await timer.timeout
	if _is_transitioning or not _intro_finished:
		return
	_advance_to_main_menu()
