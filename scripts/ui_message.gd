extends CanvasLayer

@export var default_duration: float = 2.0

var _label: Label
var _timer: Timer

func _ready() -> void:
	# Чтобы сообщения были поверх всего (затемнений, стен и т.д.)
	layer = 100 
	
	_label = Label.new()
	add_child(_label)

	_label.visible = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	# Растягиваем на весь экран с отступами
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 40
	_label.offset_right = -40
	_label.offset_top = 0
	_label.offset_bottom = -60 # Чуть выше, чтобы не прилипало к краю

	# Игнорируем мышь, чтобы текст не мешал кликать (если вдруг понадобится)
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
	
	# Если таймер уже идет, он перезапустится с новым временем
	_timer.start(duration if duration > 0.0 else default_duration)

func _on_timeout() -> void:
	_label.visible = false
