extends "res://objects/interactable/powered_switchable_interactable.gd"

@export_group("Lamp Settings")
## Лампа относится к спальне (для проверки сна).
@export var is_bedroom: bool = false

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

func _ready() -> void:
	super._ready()
	if is_bedroom and not is_in_group(GroupNames.BEDROOM_LAMP):
		add_to_group(GroupNames.BEDROOM_LAMP)
	if not is_in_group(GroupNames.LAMP):
		add_to_group(GroupNames.LAMP)
	if requires_generator and not is_in_group(GroupNames.GENERATOR_REQUIRED_LAMP):
		add_to_group(GroupNames.GENERATOR_REQUIRED_LAMP)

func _process(_delta: float) -> void:
	if _light == null or not _light.enabled:
		return
	if not flicker_enabled:
		_reset_light_energy()
		return
	var min_mult := minf(flicker_energy_min, flicker_energy_max)
	var max_mult := maxf(flicker_energy_min, flicker_energy_max)
	if randf() < flicker_chance:
		_light.energy = light_energy * randf_range(min_mult, max_mult)
		return
	_light.energy = lerp(_light.energy, light_energy, flicker_return_speed)

func _register_light_groups() -> void:
	if _light != null and not _light.is_in_group(GroupNames.LAMP_LIGHT):
		_light.add_to_group(GroupNames.LAMP_LIGHT)
