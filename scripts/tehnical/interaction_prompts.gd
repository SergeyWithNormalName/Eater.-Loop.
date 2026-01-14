extends CanvasLayer

const CHANNEL_INTERACT := "interact"
const CHANNEL_LAMP := "lamp"

const DEFAULT_INTERACT_TEXT := "E — взаимодействовать"
const DEFAULT_LAMP_ON_TEXT := "Q — включить свет"
const DEFAULT_LAMP_OFF_TEXT := "Q — выключить свет"

var _container: HBoxContainer
var _channels: Dictionary = {}
var _suspended: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.offset_left = 20
	root.offset_top = 20
	add_child(root)

	_container = HBoxContainer.new()
	_container.add_theme_constant_override("separation", 12)
	root.add_child(_container)

	_channels[CHANNEL_INTERACT] = _create_prompt_panel()
	_channels[CHANNEL_LAMP] = _create_prompt_panel()

func show_interact(source: Object, text: String = "") -> void:
	_set_prompt(CHANNEL_INTERACT, source, text if text != "" else DEFAULT_INTERACT_TEXT)

func hide_interact(source: Object) -> void:
	_clear_prompt(CHANNEL_INTERACT, source)

func show_lamp(source: Object, text: String = "") -> void:
	_set_prompt(CHANNEL_LAMP, source, text if text != "" else DEFAULT_LAMP_ON_TEXT)

func hide_lamp(source: Object) -> void:
	_clear_prompt(CHANNEL_LAMP, source)

func set_prompts_enabled(enabled: bool) -> void:
	_suspended = not enabled
	_refresh_all()

func get_default_lamp_text(is_on: bool) -> String:
	return DEFAULT_LAMP_OFF_TEXT if is_on else DEFAULT_LAMP_ON_TEXT

func _create_prompt_panel() -> Dictionary:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.custom_minimum_size = Vector2(280, 38)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 28)
	var base_font = load("res://fonts/AmaticSC-Regular.ttf")
	if base_font:
		var font_variation = FontVariation.new()
		font_variation.base_font = base_font
		font_variation.spacing_glyph = 2
		label.add_theme_font_override("font", font_variation)
	panel.add_child(label)

	_container.add_child(panel)

	return {
		"panel": panel,
		"label": label,
		"sources": {},
		"order": []
	}

func _set_prompt(channel: String, source: Object, text: String) -> void:
	if source == null:
		return
	if not _channels.has(channel):
		return
	var data: Dictionary = _channels[channel]
	var id := source.get_instance_id()
	data["sources"][id] = text
	var order: Array = data["order"]
	if order.has(id):
		order.erase(id)
	order.append(id)
	_refresh_prompt(data)

func _clear_prompt(channel: String, source: Object) -> void:
	if source == null:
		return
	if not _channels.has(channel):
		return
	var data: Dictionary = _channels[channel]
	var id := source.get_instance_id()
	if data["sources"].has(id):
		data["sources"].erase(id)
	var order: Array = data["order"]
	if order.has(id):
		order.erase(id)
	_refresh_prompt(data)

func _refresh_prompt(data: Dictionary) -> void:
	var panel: PanelContainer = data["panel"]
	var label: Label = data["label"]
	if _suspended:
		panel.visible = false
		return
	var order: Array = data["order"]
	if order.is_empty():
		label.text = ""
		panel.visible = false
		return
	var id = order.back()
	var text: String = str(data["sources"].get(id, ""))
	label.text = text
	panel.visible = text != ""

func _refresh_all() -> void:
	for data in _channels.values():
		_refresh_prompt(data)
