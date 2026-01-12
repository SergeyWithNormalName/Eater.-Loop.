extends CanvasLayer #

## Длительность показа сообщений по умолчанию.
@export var default_duration: float = 2.0 #

var _label: Label
var _timer: Timer
var _fade_rect: ColorRect

# --- Переменные для записок ---
var _note_bg: ColorRect      #
var _note_image: TextureRect #
var _is_viewing_note: bool = false #

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS #
	layer = 100 #
	
	# 1. Слой затемнения (Fade)
	_fade_rect = ColorRect.new() #
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT) #
	_fade_rect.color = Color(0, 0, 0, 0) #
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE #
	add_child(_fade_rect) #

	# 2. Текст сообщений
	_label = Label.new() #
	add_child(_label) #
	_label.visible = false #
	
	# --- НАСТРОЙКА ШРИФТА (Amatic SC) ---
	var base_font = load("res://fonts/AmaticSC-Regular.ttf")
	if base_font:
		var font_variation = FontVariation.new()
		font_variation.base_font = base_font
		# Увеличиваем расстояние между символами (glyph spacing)
		font_variation.spacing_glyph = 3 
		_label.add_theme_font_override("font", font_variation)
	
	# Увеличиваем размер шрифта ещё сильнее (было 48, стало 64)
	_label.add_theme_font_size_override("font_size", 64) 
	# ------------------------------------
	
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART #
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER #
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM #
	_label.set_anchors_preset(Control.PRESET_FULL_RECT) #
	_label.offset_left = 40 #
	_label.offset_right = -40 #
	_label.offset_top = 0 #
	_label.offset_bottom = -60 #
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE #

	_timer = Timer.new() #
	_timer.one_shot = true #
	_timer.timeout.connect(_on_timeout) #
	add_child(_timer) #
	
	_setup_note_viewer() #

func _setup_note_viewer() -> void:
	# Фон под запиской
	_note_bg = ColorRect.new() #
	_note_bg.set_anchors_preset(Control.PRESET_FULL_RECT) #
	_note_bg.color = Color(0, 0, 0, 0.7) #
	_note_bg.visible = false #
	add_child(_note_bg) #
	
	# Картинка записки
	_note_image = TextureRect.new() #
	_note_image.set_anchors_preset(Control.PRESET_CENTER) #
	_note_image.expand_mode = TextureRect.EXPAND_KEEP_SIZE #
	_note_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED #
	_note_image.visible = false #
	add_child(_note_image) #

func show_note(texture: Texture2D) -> void:
	if texture == null: return #
	_is_viewing_note = true #
	_note_image.texture = texture #
	_note_bg.visible = true #
	_note_image.visible = true #
	get_tree().paused = true #

func hide_note() -> void:
	_is_viewing_note = false #
	_note_bg.visible = false #
	_note_image.visible = false #
	get_tree().paused = false #

func _input(event: InputEvent) -> void:
	if _is_viewing_note: #
		if event.is_action_pressed("mg_cancel") or event.is_action_pressed("ui_cancel"): #
			get_viewport().set_input_as_handled() #
			hide_note() #

func show_text(text: String, duration: float = -1.0) -> void:
	var t := text.strip_edges() #
	if t == "": return #
	_label.text = t #
	_label.visible = true #
	_timer.start(duration if duration > 0.0 else default_duration) #

func _on_timeout() -> void:
	_label.visible = false #

func fade_out(duration: float = 0.5) -> void:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP #
	var tween = create_tween() #
	await tween.tween_property(_fade_rect, "color:a", 1.0, duration).finished #

func fade_in(duration: float = 0.5) -> void:
	var tween = create_tween() #
	await tween.tween_property(_fade_rect, "color:a", 0.0, duration).finished #
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE #

func change_scene_with_fade(new_scene: PackedScene, duration: float = 0.5) -> void:
	_track_scene(new_scene)
	await fade_out(duration) #
	get_tree().change_scene_to_packed(new_scene) #
	await get_tree().process_frame #
	await fade_in(duration) #

func change_scene_with_fade_delay(new_scene: PackedScene, duration: float = 0.5, post_change_delay: float = 1.0, on_dark: Callable = Callable()) -> void:
	_track_scene(new_scene)
	await fade_out(duration) #
	if on_dark.is_valid():
		on_dark.call()
	get_tree().change_scene_to_packed(new_scene) #
	await get_tree().process_frame #
	if post_change_delay > 0.0:
		await get_tree().create_timer(post_change_delay).timeout #
	await fade_in(duration) #

func _track_scene(new_scene: PackedScene) -> void:
	if GameState == null or new_scene == null:
		return
	var path := new_scene.resource_path
	if path.find("/scenes/cycles/") == -1:
		return
	GameState.set_current_scene_path(path)
	
