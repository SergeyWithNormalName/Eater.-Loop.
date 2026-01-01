extends CanvasLayer

@export var default_duration: float = 2.0

var _label: Label
var _timer: Timer
var _fade_rect: ColorRect

# --- Новые переменные для записок ---
var _note_bg: ColorRect      # Затемненный фон
var _note_image: TextureRect # Сама картинка
var _is_viewing_note: bool = false
# ------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS 
	layer = 100 
	
	# 1. Слой затемнения (Fade)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	# 2. Текст сообщений
	_label = Label.new()
	add_child(_label)
	_label.visible = false
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
	
	# 3. --- Система записок (Инициализация) ---
	_setup_note_viewer()

func _setup_note_viewer() -> void:
	# Фон под запиской (полупрозрачный черный)
	_note_bg = ColorRect.new()
	_note_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_note_bg.color = Color(0, 0, 0, 0.7) # 70% темноты
	_note_bg.visible = false
	add_child(_note_bg)
	
	# Картинка записки
	_note_image = TextureRect.new()
	_note_image.set_anchors_preset(Control.PRESET_CENTER) # По центру
	_note_image.expand_mode = TextureRect.EXPAND_KEEP_SIZE # Сохранять пропорции
	# Или используй EXPAND_FIT_HEIGHT_PROPORTIONAL, если картинки огромные
	_note_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_note_image.visible = false
	add_child(_note_image)

# --- Логика записок ---

func show_note(texture: Texture2D) -> void:
	if texture == null: return
	
	_is_viewing_note = true
	_note_image.texture = texture
	
	_note_bg.visible = true
	_note_image.visible = true
	
	# Ставим игру на паузу
	get_tree().paused = true

func hide_note() -> void:
	_is_viewing_note = false
	_note_bg.visible = false
	_note_image.visible = false
	
	# Снимаем с паузы
	get_tree().paused = false

# Обработка закрытия (работает даже на паузе благодаря process_mode = ALWAYS)
func _input(event: InputEvent) -> void:
	if _is_viewing_note:
		# Если нажата кнопка отмены (проверь название в Input Map!)
		if event.is_action_pressed("mg_cancel") or event.is_action_pressed("ui_cancel"):
			# Блокируем распространение события, чтобы меню паузы (если есть) не открылось
			get_viewport().set_input_as_handled()
			hide_note()

# --- Старые функции (Текст и Fade) ---

func show_text(text: String, duration: float = -1.0) -> void:
	var t := text.strip_edges()
	if t == "": return
	_label.text = t
	_label.visible = true
	_timer.start(duration if duration > 0.0 else default_duration)

func _on_timeout() -> void:
	_label.visible = false

func fade_out(duration: float = 0.5) -> void:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP 
	var tween = create_tween()
	await tween.tween_property(_fade_rect, "color:a", 1.0, duration).finished

func fade_in(duration: float = 0.5) -> void:
	var tween = create_tween()
	await tween.tween_property(_fade_rect, "color:a", 0.0, duration).finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene_with_fade(new_scene: PackedScene, duration: float = 0.5) -> void:
	await fade_out(duration)
	get_tree().change_scene_to_packed(new_scene)
	await get_tree().process_frame 
	await fade_in(duration)
	
