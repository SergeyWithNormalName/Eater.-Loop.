extends CanvasLayer

## Длительность показа сообщений по умолчанию.
@export var default_duration: float = 2.0

@export_group("Субтитры")
## Длительность показа субтитров по умолчанию.
@export var subtitle_duration: float = 2.5
## Размер шрифта субтитров.
@export var subtitle_font_size: int = 52

@export_group("Подсказки")
## Цвет затемнения фона подсказки.
@export var hint_overlay_color: Color = Color(0, 0, 0, 0.7)
## Цвет окна подсказки.
@export var hint_panel_color: Color = Color(0.12, 0.1, 0.08, 0.95)
## Доля ширины окна подсказки относительно экрана.
@export_range(0.4, 0.95, 0.01) var hint_panel_width_ratio: float = 0.85
## Доля высоты окна подсказки относительно экрана.
@export_range(0.4, 0.95, 0.01) var hint_panel_height_ratio: float = 0.75
## Размер шрифта текста подсказки.
@export var hint_text_font_size: int = 48
## Доля высоты окна под картинку.
@export_range(0.2, 0.8, 0.01) var hint_image_height_ratio: float = 0.45

var _label: Label
var _subtitle_label: Label
var _timer: Timer
var _subtitle_timer: Timer
var _fade_rect: ColorRect
var _sfx_player: AudioStreamPlayer
var _modules: Dictionary = {}

# --- Переменные для записок ---
var _note_bg: ColorRect
var _note_image: TextureRect
var _is_viewing_note: bool = false

# --- Переменные для подсказок ---
var _hint_bg: ColorRect
var _hint_panel: PanelContainer
var _hint_image: TextureRect
var _hint_label: Label
var _is_viewing_hint: bool = false
var _hint_prev_paused: bool = false
var _hint_pause_requested: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	# 1. Слой затемнения (Fade)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	# 2. Текст сообщений (тостеры)
	_label = Label.new()
	add_child(_label)
	_label.visible = false
	
	# --- НАСТРОЙКА ШРИФТА (Amatic SC) ---
	var base_font = load("res://fonts/AmaticSC-Regular.ttf")
	if base_font:
		var font_variation = FontVariation.new()
		font_variation.base_font = base_font
		font_variation.spacing_glyph = 3 
		_label.add_theme_font_override("font", font_variation)
	
	_label.add_theme_font_size_override("font_size", 64) 
	# ------------------------------------
	
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 40
	_label.offset_right = -40
	_label.offset_top = 0
	_label.offset_bottom = -60
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

	_subtitle_label = Label.new()
	add_child(_subtitle_label)
	_subtitle_label.visible = false

	var subtitle_font = load("res://fonts/AmaticSC-Regular.ttf")
	if subtitle_font:
		var subtitle_variation = FontVariation.new()
		subtitle_variation.base_font = subtitle_font
		subtitle_variation.spacing_glyph = 3
		_subtitle_label.add_theme_font_override("font", subtitle_variation)
	_subtitle_label.add_theme_font_size_override("font_size", subtitle_font_size)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_subtitle_label.offset_left = 60
	_subtitle_label.offset_right = -60
	_subtitle_label.offset_top = 0
	_subtitle_label.offset_bottom = -120
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_subtitle_timer = Timer.new()
	_subtitle_timer.one_shot = true
	_subtitle_timer.timeout.connect(_on_subtitle_timeout)
	add_child(_subtitle_timer)
	
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Sounds"
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_player)
	
	_setup_note_viewer()
	_setup_hint_viewer()

func _setup_note_viewer() -> void:
	_note_bg = ColorRect.new()
	_note_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_note_bg.color = Color(0, 0, 0, 0.7)
	_note_bg.visible = false
	add_child(_note_bg)
	
	_note_image = TextureRect.new()
	_note_image.set_anchors_preset(Control.PRESET_CENTER)
	_note_image.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_note_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_note_image.visible = false
	add_child(_note_image)

func _setup_hint_viewer() -> void:
	_hint_bg = ColorRect.new()
	_hint_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_bg.color = hint_overlay_color
	_hint_bg.visible = false
	_hint_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hint_bg)

	_hint_panel = PanelContainer.new()
	_hint_panel.visible = false
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hint_panel)

	# --- ИСПРАВЛЕНИЕ: Используем якоря для центрирования ---
	_hint_panel.set_anchors_preset(Control.PRESET_CENTER)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# -----------------------------------------------------

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = hint_panel_color
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(1, 1, 1, 0.15)
	_hint_panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_hint_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	_hint_image = TextureRect.new()
	_hint_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hint_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hint_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hint_image.visible = false
	vbox.add_child(_hint_image)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hint_label.add_theme_font_size_override("font_size", hint_text_font_size)
	var base_font = load("res://fonts/AmaticSC-Regular.ttf")
	if base_font:
		var font_variation = FontVariation.new()
		font_variation.base_font = base_font
		font_variation.spacing_glyph = 3
		_hint_label.add_theme_font_override("font", font_variation)
	vbox.add_child(_hint_label)

func show_note(texture: Texture2D) -> void:
	if texture == null: return
	_is_viewing_note = true
	_note_image.texture = texture
	_note_bg.visible = true
	_note_image.visible = true
	get_tree().paused = true

func hide_note() -> void:
	_is_viewing_note = false
	_note_bg.visible = false
	_note_image.visible = false
	get_tree().paused = false

func show_hint(text: String, texture: Texture2D = null, pause_game: bool = true) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	_is_viewing_hint = true
	_hint_label.text = t
	_hint_image.texture = texture
	_hint_image.visible = texture != null
	_hint_bg.color = hint_overlay_color
	_hint_bg.visible = true
	_hint_panel.visible = true
	_hint_prev_paused = get_tree().paused
	_hint_pause_requested = pause_game
	if pause_game:
		get_tree().paused = true
	_apply_hint_layout()

func hide_hint() -> void:
	if not _is_viewing_hint:
		return
	_is_viewing_hint = false
	_hint_bg.visible = false
	_hint_panel.visible = false
	if _hint_pause_requested:
		get_tree().paused = _hint_prev_paused

func _apply_hint_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
		
	# Вычисляем желаемый размер окна
	var target_size = Vector2(
		viewport_size.x * hint_panel_width_ratio,
		viewport_size.y * hint_panel_height_ratio
	)
	
	# --- ИСПРАВЛЕНИЕ: Используем custom_minimum_size вместо жесткого size и position ---
	# Это позволит контейнеру растягиваться, если текст не влезает, и при этом оставаться по центру.
	_hint_panel.custom_minimum_size = target_size
	
	# Сбрасываем текущий размер на 0, чтобы контейнер пересчитался от минимума
	_hint_panel.size = Vector2.ZERO 
	
	# Задаем высоту картинки только если она видна
	if _hint_image.visible:
		_hint_image.custom_minimum_size = Vector2(0, target_size.y * hint_image_height_ratio)
	else:
		_hint_image.custom_minimum_size = Vector2.ZERO
	# ----------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _is_viewing_hint:
		if event.is_action_pressed("mg_cancel") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			hide_hint()
			return
	if _is_viewing_note:
		if event.is_action_pressed("mg_cancel") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			hide_note()

func show_text(text: String, duration: float = -1.0) -> void:
	var t := text.strip_edges()
	if t == "": return
	_label.text = t
	_label.visible = true
	_timer.start(duration if duration > 0.0 else default_duration)

func show_subtitle(text: String, duration: float = -1.0) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	_subtitle_label.text = t
	_subtitle_label.visible = true
	_subtitle_timer.start(duration if duration > 0.0 else subtitle_duration)

func hide_subtitle() -> void:
	_subtitle_label.visible = false
	_subtitle_timer.stop()

func show_interact_prompt(source: Object, text: String = "") -> void:
	if InteractionPrompts:
		InteractionPrompts.show_interact(source, text)

func hide_interact_prompt(source: Object) -> void:
	if InteractionPrompts:
		InteractionPrompts.hide_interact(source)

func show_lamp_prompt(source: Object, text: String = "") -> void:
	if InteractionPrompts:
		InteractionPrompts.show_lamp(source, text)

func hide_lamp_prompt(source: Object) -> void:
	if InteractionPrompts:
		InteractionPrompts.hide_lamp(source)

func set_stamina_visible(is_visible: bool) -> void:
	if StaminaBar:
		StaminaBar.visible = is_visible

func register_module(name: String, node: Node) -> void:
	if name == "" or node == null:
		return
	_modules[name] = node
	if node.get_parent() == null:
		add_child(node)

func get_module(name: String) -> Node:
	return _modules.get(name, null)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.pitch_scale = pitch_scale
	_sfx_player.play()

func _on_timeout() -> void:
	_label.visible = false

func _on_subtitle_timeout() -> void:
	_subtitle_label.visible = false

func fade_out(duration: float = 0.5) -> void:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	await tween.tween_property(_fade_rect, "color:a", 1.0, duration).finished

func fade_in(duration: float = 0.5) -> void:
	var tween = create_tween()
	await tween.tween_property(_fade_rect, "color:a", 0.0, duration).finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func is_screen_dark(threshold: float = 0.01) -> bool:
	if _fade_rect == null:
		return false
	return _fade_rect.color.a > threshold

func change_scene_with_fade(new_scene: PackedScene, duration: float = 0.5) -> void:
	_track_scene(new_scene)
	await fade_out(duration)
	get_tree().change_scene_to_packed(new_scene)
	await get_tree().process_frame
	await fade_in(duration)

func change_scene_with_fade_delay(new_scene: PackedScene, duration: float = 0.5, post_change_delay: float = 1.0, on_dark: Callable = Callable()) -> void:
	_track_scene(new_scene)
	await fade_out(duration)
	if on_dark.is_valid():
		on_dark.call()
	get_tree().change_scene_to_packed(new_scene)
	await get_tree().process_frame
	if post_change_delay > 0.0:
		await get_tree().create_timer(post_change_delay).timeout
	await fade_in(duration)

func _track_scene(new_scene: PackedScene) -> void:
	if GameState == null or new_scene == null:
		return
	var path := new_scene.resource_path
	if path.find("/scenes/cycles/") == -1:
		return
	GameState.set_current_scene_path(path)
	
	
