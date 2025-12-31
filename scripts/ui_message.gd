extends CanvasLayer

@export var default_duration: float = 1.6

var _label: Label
var _timer: Timer

func _ready() -> void:
	# Label
	_label = Label.new()
	add_child(_label)

	_label.visible = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	# РАСТЯГИВАЕМ НА ЭКРАН (это главное)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 40
	_label.offset_right = -40
	_label.offset_top = 0
	_label.offset_bottom = -40  # чуть выше низа экрана

	# Чтобы клики по двери не блокировались
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Timer
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
