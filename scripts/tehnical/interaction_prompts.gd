extends CanvasLayer

const CHANNEL_INTERACT := "interact"
const CHANNEL_LAMP := "lamp"

const DEFAULT_INTERACT_TEXT := "E — взаимодействовать"
const DEFAULT_LAMP_ON_TEXT := "Q — включить свет"
const DEFAULT_LAMP_OFF_TEXT := "Q — выключить свет"

@export_group("Scenes")
@export var interact_prompt_scene: PackedScene = preload("res://scenes/ui/prompts/prompt_interact_default.tscn")
@export var lamp_prompt_scene: PackedScene = preload("res://scenes/ui/prompts/prompt_lamp_default.tscn")

@export_group("Layout")
@export var prompt_container_path: NodePath = NodePath("PromptRoot/PromptContainer")

var _container: Container
var _channels: Dictionary = {}
var _suspended: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90

	_container = get_node_or_null(prompt_container_path) as Container
	if _container == null:
		_container = _create_fallback_container()

	_channels[CHANNEL_INTERACT] = _create_prompt_panel(interact_prompt_scene)
	_channels[CHANNEL_LAMP] = _create_prompt_panel(lamp_prompt_scene)

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

func _create_fallback_container() -> Container:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.offset_left = 20
	root.offset_top = 20
	add_child(root)

	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 12)
	root.add_child(container)
	return container

func _create_prompt_panel(scene: PackedScene) -> Dictionary:
	var panel: CanvasItem = null
	if scene != null:
		var instance := scene.instantiate()
		if instance is CanvasItem:
			panel = instance
		else:
			if instance != null:
				instance.queue_free()
	if panel == null:
		panel = _create_prompt_panel_fallback()
	if panel == null:
		return {}
	panel.visible = false
	_container.add_child(panel)

	return {
		"panel": panel,
		"text_node": _find_text_node(panel),
		"sources": {},
		"order": []
	}

func _create_prompt_panel_fallback() -> PanelContainer:
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

	return panel

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
	var panel: Node = data.get("panel")
	if _suspended:
		_set_panel_visible(panel, false)
		return
	var order: Array = data["order"]
	if order.is_empty():
		_set_prompt_text(data, "")
		_set_panel_visible(panel, false)
		return
	var id = order.back()
	var text: String = str(data["sources"].get(id, ""))
	_set_prompt_text(data, text)
	_set_panel_visible(panel, text != "")

func _set_prompt_text(data: Dictionary, text: String) -> void:
	var panel: Node = data.get("panel")
	if panel == null:
		return
	if panel.has_method("set_prompt_text"):
		panel.call("set_prompt_text", text)
		return
	var text_node: Node = data.get("text_node")
	if text_node == null or not is_instance_valid(text_node):
		text_node = _find_text_node(panel)
		data["text_node"] = text_node
	if text_node != null:
		text_node.set("text", text)

func _set_panel_visible(panel: Node, visible: bool) -> void:
	if panel == null:
		return
	if panel is CanvasItem:
		panel.visible = visible
	elif panel.has_method("set_visible"):
		panel.call("set_visible", visible)

func _find_text_node(node: Node) -> Node:
	if node is Label or node is RichTextLabel:
		return node
	for child in node.get_children():
		var found := _find_text_node(child)
		if found != null:
			return found
	return null

func _refresh_all() -> void:
	for data in _channels.values():
		_refresh_prompt(data)
