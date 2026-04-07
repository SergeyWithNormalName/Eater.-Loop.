extends InteractiveObject
class_name PoweredSwitchableInteractable

@export_group("Power Settings")
@export var requires_generator: bool = false
@export var start_on: bool = false
@export_multiline var no_power_message: String = "Нет электричества."

@export_group("Switch Feedback")
@export var turn_on_sfx: AudioStream
@export var turn_on_volume_db: float = 0.0
@export_range(0.5, 1.5, 0.01) var switch_pitch_min: float = 0.95
@export_range(0.5, 1.5, 0.01) var switch_pitch_max: float = 1.05

@export_group("Light Settings")
@export var light_node: NodePath = NodePath("PointLight2D")
@export var light_color: Color = Color(1.0, 0.95, 0.8)
@export var light_range: float = 450.0
@export var light_energy: float = 1.0

@export_group("Sprite Settings")
@export var sprite_node: NodePath = NodePath("Sprite2D")
@export var off_texture: Texture2D
@export var on_texture: Texture2D

var _is_on: bool = false
var _has_power: bool = false
var _light: PointLight2D = null
var _sprite: Sprite2D = null

func _ready() -> void:
	super._ready()
	_light = get_node_or_null(light_node) as PointLight2D
	if _light != null:
		_apply_light_settings()
		_register_light_groups()
	if not is_in_group(GroupNames.REACTIVE_LIGHT_SOURCE):
		add_to_group(GroupNames.REACTIVE_LIGHT_SOURCE)
	if requires_generator and not is_in_group(GroupNames.GENERATOR_REQUIRED_LIGHT):
		add_to_group(GroupNames.GENERATOR_REQUIRED_LIGHT)
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	if _sprite != null and off_texture == null:
		off_texture = _sprite.texture
	_has_power = not requires_generator
	_is_on = start_on
	_update_output_state(false)

func set_powered(enabled: bool) -> void:
	_has_power = enabled
	if enabled:
		_is_on = true
	_update_output_state(true)

func turn_on() -> void:
	set_powered(true)

func is_light_active() -> bool:
	return _light != null and _light.enabled

func is_point_lit(point: Vector2) -> bool:
	if not is_light_active():
		return false
	var origin := ReactiveLightUtils.resolve_light_origin(_light)
	var resolved_light_range := ReactiveLightUtils.resolve_point_light_range(_light, light_range)
	return ReactiveLightUtils.is_point_within_radius(origin, point, resolved_light_range)

func _get_interact_action() -> String:
	return "lamp_switch"

func _on_interact() -> void:
	_toggle()

func _toggle() -> void:
	if not _has_power:
		_show_no_power_message()
		return
	_is_on = not _is_on
	_update_output_state(true)

func _show_prompt() -> void:
	var text := _get_switch_prompt_text()
	if UIMessage:
		UIMessage.show_lamp_prompt(self, text)
	elif InteractionPrompts:
		InteractionPrompts.show_lamp(self, text)

func _hide_prompt() -> void:
	if UIMessage:
		UIMessage.hide_lamp_prompt(self)
	elif InteractionPrompts:
		InteractionPrompts.hide_lamp(self)

func _get_switch_prompt_text() -> String:
	if InteractionPrompts and InteractionPrompts.has_method("get_default_lamp_text"):
		return tr(String(InteractionPrompts.get_default_lamp_text(_is_on)))
	return tr("Q — выключить свет") if _is_on else tr("Q — включить свет")

func _show_no_power_message() -> void:
	if UIMessage:
		UIMessage.show_notification(str(no_power_message))

func _update_output_state(play_sound: bool) -> void:
	var should_enable := _is_on and _has_power
	var was_enabled := false
	if _light != null:
		was_enabled = _light.enabled
		_light.enabled = should_enable
		_reset_light_energy()
		if play_sound and was_enabled != should_enable:
			play_feedback_sfx(
				turn_on_sfx,
				turn_on_volume_db,
				minf(switch_pitch_min, switch_pitch_max),
				maxf(switch_pitch_min, switch_pitch_max)
			)
	_update_sprite(should_enable)
	_refresh_switch_prompt()

func _refresh_switch_prompt() -> void:
	if is_player_in_range():
		_show_prompt()

func _register_light_groups() -> void:
	pass

func _apply_light_settings() -> void:
	if _light == null:
		return
	_light.color = light_color
	_reset_light_energy()
	_update_light_range()

func _update_light_range() -> void:
	if _light == null or _light.texture == null:
		return
	var base_radius := maxf(_light.texture.get_width(), _light.texture.get_height()) * 0.5
	if base_radius <= 0.0:
		return
	_light.texture_scale = maxf(1.0, light_range) / base_radius

func _reset_light_energy() -> void:
	if _light != null and _light.energy != light_energy:
		_light.energy = light_energy

func _update_sprite(is_lit: bool) -> void:
	if _sprite == null:
		return
	if is_lit and on_texture != null:
		_sprite.texture = on_texture
	elif off_texture != null:
		_sprite.texture = off_texture

func capture_checkpoint_state() -> Dictionary:
	var state := super.capture_checkpoint_state()
	state["is_on"] = _is_on
	state["has_power"] = _has_power
	return state

func apply_checkpoint_state(state: Dictionary) -> void:
	super.apply_checkpoint_state(state)
	_is_on = bool(state.get("is_on", _is_on))
	_has_power = bool(state.get("has_power", _has_power))
	_update_output_state(false)
