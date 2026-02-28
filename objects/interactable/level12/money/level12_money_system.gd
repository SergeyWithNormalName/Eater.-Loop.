extends Node

signal money_changed(current_money: int, delta: int, reason: String)
signal passage_check(current_money: int, required_money: int, can_pass: bool)

@export var required_money: int = 100
@export_range(0.5, 10.0, 0.1) var hud_show_duration: float = 3.0
@export var hud_font_size: int = 52
@export var hud_left_margin: int = 24
@export var hud_bottom_margin: int = 24

var _money: int = 0
var _hud_layer: CanvasLayer = null
var _hud_label: Label = null
var _hud_timer: Timer = null

func _ready() -> void:
	_setup_hud()

func get_money() -> int:
	return _money

func add_money(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	_money += amount
	money_changed.emit(_money, amount, reason)

	var header := "+%d RUB" % amount
	var note := reason.strip_edges()
	if note != "":
		header = "%s\n%s" % [header, note]
	_show_hud("%s\nMoney: %d/%d RUB" % [header, _money, required_money])

func has_enough_money(required_money_override: int = -1) -> bool:
	return _money >= _resolve_required_money(required_money_override)

func try_open_blockpost(required_money_override: int = -1) -> bool:
	var needed := _resolve_required_money(required_money_override)
	var can_pass := _money >= needed
	passage_check.emit(_money, needed, can_pass)

	if can_pass:
		_show_hud("Money: %d/%d RUB\nYou can pass." % [_money, needed])
	else:
		_show_hud("Money: %d/%d RUB\nNeed %d more RUB." % [_money, needed, needed - _money])

	return can_pass

func _resolve_required_money(required_money_override: int) -> int:
	if required_money_override >= 0:
		return required_money_override
	return max(0, required_money)

func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 120
	add_child(_hud_layer)

	_hud_label = Label.new()
	_hud_label.visible = false
	_hud_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_label.offset_left = hud_left_margin
	_hud_label.offset_right = -24
	_hud_label.offset_top = 0
	_hud_label.offset_bottom = -hud_bottom_margin
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hud_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hud_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_label.add_theme_font_size_override("font_size", hud_font_size)

	var font := load("res://global/fonts/AmaticSC-Regular.ttf")
	if font:
		var variation := FontVariation.new()
		variation.base_font = font
		variation.spacing_glyph = 3
		_hud_label.add_theme_font_override("font", variation)

	_hud_layer.add_child(_hud_label)

	_hud_timer = Timer.new()
	_hud_timer.one_shot = true
	_hud_timer.timeout.connect(_on_hud_timeout)
	add_child(_hud_timer)

func _show_hud(text: String) -> void:
	if _hud_label == null or _hud_timer == null:
		return
	_hud_label.text = text
	_hud_label.visible = true
	_hud_timer.start(max(0.1, hud_show_duration))

func _on_hud_timeout() -> void:
	if _hud_label:
		_hud_label.visible = false
