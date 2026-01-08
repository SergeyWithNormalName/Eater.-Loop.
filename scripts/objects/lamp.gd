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

@export_group("Light Settings")
## Узел PointLight2D для света.
@export var light_node: NodePath = NodePath("PointLight2D")
## Цвет света лампы.
@export var light_color: Color = Color(1.0, 0.95, 0.8)
## Дальность света (масштаб текстуры света).
@export var light_range: float = 450.0
## Энергия света.
@export var light_energy: float = 1.0

var _player_inside: bool = false
var _is_on: bool = false
var _light: PointLight2D = null
var _interact_area: Area2D = null
var _sfx_player: AudioStreamPlayer2D

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

	_is_on = start_on
	_update_light_enabled(false)

	_sfx_player = AudioStreamPlayer2D.new()
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

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _toggle() -> void:
	if _is_on:
		_is_on = false
		_update_light_enabled(false)
		return

	if not _has_power():
		UIMessage.show_text(no_power_message)
		return

	_is_on = true
	_update_light_enabled(true)

func _has_power() -> bool:
	if GameState == null:
		return true
	return GameState.electricity_on

func _update_light_enabled(play_sound: bool) -> void:
	if _light == null:
		return
	var should_enable = _is_on and _has_power()
	var was_enabled = _light.enabled
	_light.enabled = should_enable
	if play_sound and should_enable and not was_enabled:
		_play_turn_on_sound()

func _play_turn_on_sound() -> void:
	if turn_on_sfx == null:
		return
	_sfx_player.stream = turn_on_sfx
	_sfx_player.volume_db = turn_on_volume_db
	_sfx_player.pitch_scale = 1.0
	_sfx_player.play()

func _apply_light_settings() -> void:
	if _light == null:
		return
	_light.color = light_color
	_light.energy = light_energy
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

func _on_electricity_changed(_is_on: bool) -> void:
	_update_light_enabled(true)

func is_light_active() -> bool:
	return _light != null and _light.enabled
