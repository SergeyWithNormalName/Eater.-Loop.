extends CanvasLayer

@export var default_duration: float = 2.0

var _label: Label
var _timer: Timer
var _fade_rect: ColorRect

func _ready() -> void:
	# === ВАЖНОЕ ИСПРАВЛЕНИЕ ===
	# Эта настройка разрешает скрипту работать, даже когда включена пауза (в мини-играх)
	process_mode = Node.PROCESS_MODE_ALWAYS 
	# ==========================
	
	layer = 100 
	
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

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

func show_text(text: String, duration: float = -1.0) -> void:
	var t := text.strip_edges()
	if t == "":
		return
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
	
