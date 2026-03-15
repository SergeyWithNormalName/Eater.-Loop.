extends InteractiveObject

@export_group("Projector Settings")
@export var requires_generator: bool = false
@export var start_on: bool = false
@export var turn_on_sfx: AudioStream = preload("res://objects/interactable/lamp/lamp.wav")
@export var turn_on_volume_db: float = 0.0
@export_range(0.5, 1.5, 0.01) var switch_pitch_min: float = 0.95
@export_range(0.5, 1.5, 0.01) var switch_pitch_max: float = 1.05

@export_group("Light Settings")
@export var light_node: NodePath = NodePath("PointLight2D")
@export var light_color: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var light_range: float = 1100.0
@export var light_energy: float = 1.6
@export_range(1.0, 180.0, 1.0) var light_fov_deg: float = 36.0
@export var beam_direction_local: Vector2 = Vector2.RIGHT

@export_group("Sprite Settings")
@export var sprite_node: NodePath = NodePath("Sprite2D")
@export var off_texture: Texture2D
@export var on_texture: Texture2D

var _is_on: bool = false
var _has_power: bool = false
var _light: PointLight2D = null
var _sprite: Sprite2D = null
var _sfx_player: AudioStreamPlayer2D = null

func _ready() -> void:
	super._ready()

	_light = get_node_or_null(light_node) as PointLight2D
	if _light != null:
		_apply_light_settings()
	if not is_in_group("reactive_light_source"):
		add_to_group("reactive_light_source")
	if requires_generator and not is_in_group("generator_required_light"):
		add_to_group("generator_required_light")

	_sprite = get_node_or_null(sprite_node) as Sprite2D
	if _sprite != null and off_texture == null:
		off_texture = _sprite.texture

	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.bus = "Sounds"
	_sfx_player.volume_db = turn_on_volume_db
	add_child(_sfx_player)

	_has_power = not requires_generator
	_is_on = start_on
	_update_light_enabled(false)

func turn_on() -> void:
	_has_power = true
	_is_on = true
	_update_light_enabled(true)

func is_light_active() -> bool:
	return _light != null and _light.enabled

func is_point_lit(point: Vector2) -> bool:
	if not is_light_active():
		return false
	var origin := ReactiveLightUtils.resolve_light_origin(_light)
	var facing := _resolve_beam_direction()
	return ReactiveLightUtils.is_point_within_cone(origin, facing, point, light_range, light_fov_deg)

func _get_interact_action() -> String:
	return "lamp_switch"

func _on_interact() -> void:
	_toggle()

func _toggle() -> void:
	if not _has_power:
		if UIMessage:
			UIMessage.show_notification("Нет электричества.")
		return
	_is_on = not _is_on
	_update_light_enabled(true)

func _show_prompt() -> void:
	var text := _get_projector_prompt_text()
	if UIMessage:
		UIMessage.show_lamp_prompt(self, text)
	elif InteractionPrompts:
		InteractionPrompts.show_lamp(self, text)

func _hide_prompt() -> void:
	if UIMessage:
		UIMessage.hide_lamp_prompt(self)
	elif InteractionPrompts:
		InteractionPrompts.hide_lamp(self)

func _get_projector_prompt_text() -> String:
	if is_light_active():
		return tr("Q — выключить проектор")
	return tr("Q — включить проектор")

func _update_light_enabled(play_sound: bool) -> void:
	var should_enable := _is_on and _has_power
	var was_enabled := false
	if _light != null:
		was_enabled = _light.enabled
		_light.enabled = should_enable
		_light.color = light_color
		_light.energy = light_energy
		if play_sound and was_enabled != should_enable:
			_play_switch_sound()
	_update_sprite(should_enable)
	if is_player_in_range():
		_show_prompt()

func _apply_light_settings() -> void:
	if _light == null:
		return
	_light.color = light_color
	_light.energy = light_energy
	_update_light_range()

func _update_light_range() -> void:
	if _light == null or _light.texture == null:
		return
	var base_radius := maxf(_light.texture.get_width(), _light.texture.get_height()) * 0.5
	if base_radius <= 0.0:
		return
	_light.texture_scale = maxf(1.0, light_range) / base_radius

func _update_sprite(is_lit: bool) -> void:
	if _sprite == null:
		return
	if is_lit and on_texture != null:
		_sprite.texture = on_texture
	elif not is_lit and off_texture != null:
		_sprite.texture = off_texture
	elif on_texture == null and off_texture == null:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_lit else Color(0.72, 0.72, 0.72, 1.0)

func _play_switch_sound() -> void:
	if turn_on_sfx == null or _sfx_player == null:
		return
	_sfx_player.stream = turn_on_sfx
	_sfx_player.volume_db = turn_on_volume_db
	_sfx_player.pitch_scale = randf_range(minf(switch_pitch_min, switch_pitch_max), maxf(switch_pitch_min, switch_pitch_max))
	_sfx_player.play()

func _resolve_beam_direction() -> Vector2:
	var local_direction := beam_direction_local
	if local_direction.length_squared() <= 0.000001:
		local_direction = Vector2.RIGHT
	var facing := global_transform.basis_xform(local_direction.normalized())
	if facing.length_squared() <= 0.000001:
		return Vector2.RIGHT
	return facing.normalized()

func capture_checkpoint_state() -> Dictionary:
	var state := super.capture_checkpoint_state()
	state["is_on"] = _is_on
	state["has_power"] = _has_power
	return state

func apply_checkpoint_state(state: Dictionary) -> void:
	super.apply_checkpoint_state(state)
	_is_on = bool(state.get("is_on", _is_on))
	_has_power = bool(state.get("has_power", _has_power))
	_update_light_enabled(false)
