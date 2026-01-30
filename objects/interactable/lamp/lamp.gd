extends InteractiveObject # Убедись, что наследуешься от обновленного класса

@export_group("Lamp Settings")
## Лампа относится к спальне (для проверки сна).
@export var is_bedroom: bool = false
## Включена ли лампа при старте (автоматически дает электричество).
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

# Внутренние переменные
var _is_on: bool = false
var _has_power: bool = false # <-- Новая переменная вместо GameState
var _light: PointLight2D = null
var _sfx_player: AudioStreamPlayer2D
var _sprite: Sprite2D = null

func _ready() -> void:
	super._ready() # Вызов ready базового класса (важно для Area2D)
	
	_light = get_node_or_null(light_node) as PointLight2D
	if _light:
		_apply_light_settings()
		if not _light.is_in_group("lamp_light"):
			_light.add_to_group("lamp_light")

	_sprite = get_node_or_null(sprite_node) as Sprite2D
	if _sprite and off_texture == null:
		off_texture = _sprite.texture

	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.bus = "Sounds"
	_sfx_player.volume_db = turn_on_volume_db
	add_child(_sfx_player)

	if is_bedroom and not is_in_group("bedroom_lamp"):
		add_to_group("bedroom_lamp")
	if not is_in_group("lamp"):
		add_to_group("lamp")
	
	# ИСПРАВЛЕНИЕ: Логика инициализации состояния
	if start_on:
		_has_power = true
		_is_on = true
	else:
		_has_power = false
		_is_on = false
		
	# Применяем состояние (false = без звука при старте)
	_update_light_enabled(false)

# --- ЭТОТ МЕТОД ВЫЗЫВАЕТ ГЕНЕРАТОР ---
func turn_on() -> void:
	_has_power = true
	_is_on = true # Сразу включаем, когда дали ток
	_update_light_enabled(true) # true = проиграть звук

func _get_interact_action() -> String:
	# Если у тебя в Input Map настроено действие "lamp_switch", оставь как есть.
	# Если нет, используй стандартный "interact"
	return "lamp_switch" 

func _on_interact() -> void:
	_toggle()

func _toggle() -> void:
	# Если нет питания — выводим сообщение из InteractiveObject
	if not _has_power:
		# Можно использовать встроенный locked_message базового класса,
		# но у тебя тут кастомное сообщение было, оставим его вызов через UIMessage
		if UIMessage:
			UIMessage.show_message("Нет электричества.")
		return

	_is_on = !_is_on
	_update_light_enabled(true)
	_update_prompt()

func _update_light_enabled(play_sound: bool) -> void:
	var should_enable = _is_on and _has_power
	var was_enabled = false
	if _light != null:
		was_enabled = _light.enabled
		_light.enabled = should_enable
		_reset_light_energy()
		# Играем звук только если состояние реально изменилось
		if play_sound and was_enabled != should_enable:
			_play_switch_sound()
	_update_sprite(should_enable)
	_update_prompt()

func _process(_delta: float) -> void:
	if _light == null or not _light.enabled:
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

func _show_prompt() -> void:
	var text := _get_lamp_prompt_text()
	if UIMessage:
		UIMessage.show_lamp_prompt(self, text)
	elif InteractionPrompts:
		InteractionPrompts.show_lamp(self, text)

func _hide_prompt() -> void:
	if UIMessage:
		UIMessage.hide_lamp_prompt(self)
	elif InteractionPrompts:
		InteractionPrompts.hide_lamp(self)

func _get_lamp_prompt_text() -> String:
	if InteractionPrompts and InteractionPrompts.has_method("get_default_lamp_text"):
		return InteractionPrompts.get_default_lamp_text(_is_on)
	return "Q — выключить свет" if _is_on else "Q — включить свет"

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
	if _light == null or _light.texture == null:
		return
	var base_radius = max(_light.texture.get_width(), _light.texture.get_height()) * 0.5
	if base_radius <= 0.0: return
	var range_val = max(1.0, light_range)
	_light.texture_scale = range_val / base_radius

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

func _update_prompt() -> void:
	if is_player_in_range():
		_show_prompt()
		
		
