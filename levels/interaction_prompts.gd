extends Node2D

const CHANNEL_INTERACT := "interact"
const CHANNEL_LAMP := "lamp"

const DEFAULT_INTERACT_TEXT := "E — взаимодействовать"
const DEFAULT_LAMP_ON_TEXT := "Q — включить свет"
const DEFAULT_LAMP_OFF_TEXT := "Q — выключить свет"
const INPUT_KIND_KEYBOARD := 0
const INPUT_KIND_GAMEPAD_SONY := 1
const INPUT_KIND_GAMEPAD_OTHER := 2
const INPUT_KIND_UNKNOWN := -1
const JOYPAD_MOTION_DEADZONE := 0.45
const SONY_JOYPAD_GUID_VENDOR_HINT := "054c"
const SONY_JOYPAD_NAME_HINTS := [
	"sony",
	"dualsense",
	"dualshock",
	"playstation",
	"wireless controller",
	"ps3",
	"ps4",
	"ps5"
]

@export_group("Indicator")
@export var button_texture: Texture2D = preload("res://player/UI_Button_Sprite.png")
@export var button_texture_dualsense: Texture2D = preload("res://player/UI_Button_Sprite_Dualsense.png")
@export var button_texture_xbox: Texture2D = preload("res://player/UI_Button_Sprite_Xbox.png")
@export var indicator_scale: Vector2 = Vector2(0.1, 0.1)
@export var indicator_z_index: int = 1

var _channels: Dictionary = {}
var _suspended: bool = false
var _input_kind: int = INPUT_KIND_KEYBOARD

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_channels[CHANNEL_INTERACT] = _create_channel_sprite()
	_channels[CHANNEL_LAMP] = _create_channel_sprite()
	_apply_input_texture_to_channels()

func _input(event: InputEvent) -> void:
	var next_input_kind := _resolve_input_kind(event)
	if next_input_kind == INPUT_KIND_UNKNOWN:
		return
	if next_input_kind == _input_kind:
		return
	_input_kind = next_input_kind
	_apply_input_texture_to_channels()

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
	sprite.texture = _resolve_active_texture()
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

func _resolve_input_kind(event: InputEvent) -> int:
	if event == null or event.is_echo():
		return INPUT_KIND_UNKNOWN
	if event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		if not joy_button.pressed:
			return INPUT_KIND_UNKNOWN
		return INPUT_KIND_GAMEPAD_SONY if _is_sony_gamepad(joy_button.device) else INPUT_KIND_GAMEPAD_OTHER
	if event is InputEventJoypadMotion:
		var joy_motion := event as InputEventJoypadMotion
		if absf(joy_motion.axis_value) < JOYPAD_MOTION_DEADZONE:
			return INPUT_KIND_UNKNOWN
		return INPUT_KIND_GAMEPAD_SONY if _is_sony_gamepad(joy_motion.device) else INPUT_KIND_GAMEPAD_OTHER
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed:
			return INPUT_KIND_UNKNOWN
		return INPUT_KIND_KEYBOARD
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed:
			return INPUT_KIND_UNKNOWN
		return INPUT_KIND_KEYBOARD
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if mouse_motion.relative.length_squared() <= 0.0:
			return INPUT_KIND_UNKNOWN
		return INPUT_KIND_KEYBOARD
	return INPUT_KIND_UNKNOWN

func _is_sony_gamepad(device_id: int) -> bool:
	if device_id < 0:
		return false
	var joy_name := Input.get_joy_name(device_id).to_lower()
	for hint in SONY_JOYPAD_NAME_HINTS:
		if joy_name.find(hint) >= 0:
			return true
	var joy_guid := Input.get_joy_guid(device_id).to_lower()
	return joy_guid.find(SONY_JOYPAD_GUID_VENDOR_HINT) >= 0

func _resolve_active_texture() -> Texture2D:
	if _input_kind == INPUT_KIND_GAMEPAD_SONY and button_texture_dualsense != null:
		return button_texture_dualsense
	if _input_kind == INPUT_KIND_GAMEPAD_OTHER and button_texture_xbox != null:
		return button_texture_xbox
	return button_texture

func _apply_input_texture_to_channels() -> void:
	var texture := _resolve_active_texture()
	for data in _channels.values():
		var sprite: Sprite2D = data.get("sprite")
		if sprite != null:
			sprite.texture = texture
