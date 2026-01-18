extends Area2D

@export_group("Interaction")
## Узел Area2D для зоны взаимодействия (пусто — использовать сам объект).
@export var interact_area_node: NodePath = NodePath("")
## Сообщение, если нет электричества.
@export_multiline var no_power_message: String = "Нет электричества."

@export_group("Lamp Settings")
## Лампа относится к спальне (для проверки сна).
@export var is_bedroom: bool = false
## Включена ли лампа при старте.
@export var start_on: bool = false
## Звук включения лампы.
@export var turn_on_sfx: AudioStream
## Громкость звука включения в дБ.
@export var turn_on_volume_db: float = 0.0
## Минимальная высота тона звука (для разнообразия).
@export_range(0.5, 1.5, 0.01) var switch_pitch_min: float = 0.95
## Максимальная высота тона звука (для разнообразия).
@export_range(0.5, 1.5, 0.01) var switch_pitch_max: float = 1.05

@export_group("Light Settings")
## Узел PointLight2D для света.
@export var light_node: NodePath = NodePath("PointLight2D")
## Цвет света лампы.
@export var light_color: Color = Color(1.0, 0.95, 0.8)
## Дальность света (масштаб текстуры света).
@export var light_range: float = 450.0
## Энергия света.
@export var light_energy: float = 1.0

@export_group("Flicker Settings")
## Включить мерцание света.
@export var flicker_enabled: bool = false
## Шанс мерцания на кадр.
@export_range(0.0, 1.0, 0.01) var flicker_chance: float = 0.05
## Минимальный множитель энергии при мерцании.
@export_range(0.0, 2.0, 0.01) var flicker_energy_min: float = 0.8
## Максимальный множитель энергии при мерцании.
@export_range(0.0, 2.0, 0.01) var flicker_energy_max: float = 1.1
## Скорость возвращения энергии к базовой.
@export_range(0.0, 1.0, 0.01) var flicker_return_speed: float = 0.1

@export_group("Sprite Settings")
## Узел Sprite2D лампы.
@export var sprite_node: NodePath = NodePath("Sprite2D")
## Текстура выключенной лампы.
@export var off_texture: Texture2D
## Текстура включенной лампы.
@export var on_texture: Texture2D

var _player_inside: bool = false
var _is_on: bool = false
var _light: PointLight2D = null
var _interact_area: Area2D = null
var _sfx_player: AudioStreamPlayer2D
var _sprite: Sprite2D = null

func _ready() -> void:
	input_pickable = false

	_interact_area = get_node_or_null(interact_area_node) as Area2D
	if _interact_area == null:
		_interact_area = self
	if _interact_area:
		if not _interact_area.body_entered.is_connected(_on_body_entered):
			_interact_area.body_entered.connect(_on_body_entered)
		if not _interact_area.body_exited.is_connected(_on_body_exited):
			_interact_area.body_exited.connect(_on_body_exited)

	_light = get_node_or_null(light_node) as PointLight2D
	if _light:
		_apply_light_settings()
		if not _light.is_in_group("lamp_light"):
			_light.add_to_group("lamp_light")

	_sprite = get_node_or_null(sprite_node) as Sprite2D
	if _sprite and off_texture == null:
		off_texture = _sprite.texture

	_is_on = start_on
	_update_light_enabled(false)

	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.bus = "Sounds"
	_sfx_player.volume_db = turn_on_volume_db
	add_child(_sfx_player)

	if is_bedroom and not is_in_group("bedroom_lamp"):
		add_to_group("bedroom_lamp")
	if not is_in_group("lamp"):
		add_to_group("lamp")

	if GameState and GameState.has_signal("electricity_changed"):
		GameState.electricity_changed.connect(_on_electricity_changed)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_pressed("lamp_switch"):
		_toggle()

func _process(_delta: float) -> void:
	if _light == null:
		return
	if not _light.enabled:
		_reset_light_energy()
		return
	if not flicker_enabled:
		_reset_light_energy()
		return

	var min_mult: float = min(flicker_energy_min, flicker_energy_max)
	var max_mult: float = max(flicker_energy_min, flicker_energy_max)
	if randf() < flicker_chance:
		_light.energy = light_energy * randf_range(min_mult, max_mult)
	else:
		_light.energy = lerp(_light.energy, light_energy, flicker_return_speed)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_update_prompt()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if InteractionPrompts:
			InteractionPrompts.hide_lamp(self)

func _toggle() -> void:
	if _is_on:
		_is_on = false
		_update_light_enabled(false)
		_play_switch_sound()
		_update_prompt()
		return

	if not _has_power():
		UIMessage.show_text(no_power_message)
		return

	_is_on = true
	_update_light_enabled(true)
	_play_switch_sound()
	_update_prompt()

func _has_power() -> bool:
	if GameState == null:
		return true
	return GameState.electricity_on

func _update_light_enabled(play_sound: bool) -> void:
	var should_enable = _is_on and _has_power()
	var was_enabled = false
	if _light != null:
		was_enabled = _light.enabled
		_light.enabled = should_enable
		_reset_light_energy()
		if play_sound and was_enabled != should_enable:
			_play_switch_sound()
	_update_sprite(should_enable)
	_update_prompt()

func _play_switch_sound() -> void:
	if turn_on_sfx == null:
		return
	_sfx_player.stream = turn_on_sfx
	_sfx_player.volume_db = turn_on_volume_db
	var min_pitch: float = min(switch_pitch_min, switch_pitch_max)
	var max_pitch: float = max(switch_pitch_min, switch_pitch_max)
	_sfx_player.pitch_scale = randf_range(min_pitch, max_pitch)
	_sfx_player.play()

func _apply_light_settings() -> void:
	if _light == null:
		return
	_light.color = light_color
	_reset_light_energy()
	_update_light_range()

func _update_light_range() -> void:
	if _light == null:
		return
	if _light.texture == null:
		return
	var base_radius = max(_light.texture.get_width(), _light.texture.get_height()) * 0.5
	if base_radius <= 0.0:
		return
	var range_val = max(1.0, light_range)
	_light.texture_scale = range_val / base_radius

func _reset_light_energy() -> void:
	if _light == null:
		return
	if _light.energy != light_energy:
		_light.energy = light_energy

func _update_sprite(is_lit: bool) -> void:
	if _sprite == null:
		return
	if is_lit and on_texture != null:
		_sprite.texture = on_texture
	elif off_texture != null:
		_sprite.texture = off_texture

func _on_electricity_changed(_is_on: bool) -> void:
	_update_light_enabled(true)

func is_light_active() -> bool:
	return _light != null and _light.enabled

func _update_prompt() -> void:
	if not InteractionPrompts:
		return
	if not _player_inside:
		return
	InteractionPrompts.show_lamp(self, InteractionPrompts.get_default_lamp_text(_is_on))
