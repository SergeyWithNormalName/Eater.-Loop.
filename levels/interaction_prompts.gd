extends Node2D

const CHANNEL_INTERACT := "interact"
const CHANNEL_LAMP := "lamp"

const DEFAULT_INTERACT_TEXT := "E — взаимодействовать"
const DEFAULT_LAMP_ON_TEXT := "Q — включить свет"
const DEFAULT_LAMP_OFF_TEXT := "Q — выключить свет"

@export_group("Indicator")
@export var button_texture: Texture2D = preload("res://player/UI_Button_Sprite.png")
@export var indicator_scale: Vector2 = Vector2(0.1, 0.1)
@export var indicator_z_index: int = 1

var _channels: Dictionary = {}
var _suspended: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_channels[CHANNEL_INTERACT] = _create_channel_sprite()
	_channels[CHANNEL_LAMP] = _create_channel_sprite()

func _process(_delta: float) -> void:
	if _suspended:
		return
	for data in _channels.values():
		_update_channel_position(data)

func show_interact(source: Object, _text: String = "") -> void:
	_set_prompt(CHANNEL_INTERACT, source)

func hide_interact(source: Object) -> void:
	_clear_prompt(CHANNEL_INTERACT, source)

func show_lamp(source: Object, _text: String = "") -> void:
	_set_prompt(CHANNEL_LAMP, source)

func hide_lamp(source: Object) -> void:
	_clear_prompt(CHANNEL_LAMP, source)

func set_prompts_enabled(enabled: bool) -> void:
	_suspended = not enabled
	_refresh_all()

func are_prompts_enabled() -> bool:
	return not _suspended

func get_default_lamp_text(is_on: bool) -> String:
	return DEFAULT_LAMP_OFF_TEXT if is_on else DEFAULT_LAMP_ON_TEXT

func _create_channel_sprite() -> Dictionary:
	var sprite := Sprite2D.new()
	sprite.visible = false
	sprite.centered = true
	sprite.texture = button_texture
	sprite.scale = indicator_scale
	sprite.z_index = indicator_z_index
	add_child(sprite)

	return {
		"sprite": sprite,
		"sources": {},
		"order": [],
		"active_source": null
	}

func _set_prompt(channel: String, source: Object) -> void:
	if source == null:
		return
	if not _channels.has(channel):
		return
	var data: Dictionary = _channels[channel]
	var id := source.get_instance_id()
	data["sources"][id] = source
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
	var sprite: Sprite2D = data.get("sprite")
	if _suspended:
		_set_sprite_visible(sprite, false)
		data["active_source"] = null
		return
	var order: Array = data["order"]
	if order.is_empty():
		_set_sprite_visible(sprite, false)
		data["active_source"] = null
		return
	var id = order.back()
	var source: Object = data["sources"].get(id, null)
	if source == null or not is_instance_valid(source):
		data["sources"].erase(id)
		order.erase(id)
		_refresh_prompt(data)
		return
	data["active_source"] = source
	_update_channel_position(data)

func _update_channel_position(data: Dictionary) -> void:
	var sprite: Sprite2D = data.get("sprite")
	if sprite == null:
		return
	var source: Object = data.get("active_source")
	if source == null or not is_instance_valid(source):
		data["active_source"] = null
		_set_sprite_visible(sprite, false)
		return
	var pos: Variant = _try_get_prompt_world_position(source)
	if pos == null:
		_set_sprite_visible(sprite, false)
		return
	sprite.global_position = pos
	_set_sprite_visible(sprite, true)

func _try_get_prompt_world_position(source: Object) -> Variant:
	if source == null:
		return null
	if source.has_method("get_prompt_world_position"):
		var pos = source.call("get_prompt_world_position")
		if pos is Vector2:
			return pos
	if source is Node2D:
		return (source as Node2D).global_position
	return null

func _set_sprite_visible(sprite: Sprite2D, visible_state: bool) -> void:
	if sprite == null:
		return
	sprite.visible = visible_state

func _refresh_all() -> void:
	for data in _channels.values():
		_refresh_prompt(data)
