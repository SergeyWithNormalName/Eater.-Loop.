extends PointLight2D

@export var shake_intensity: float = 2.0
@export var flicker_chance: float = 0.05
@export var base_energy: float = 1.0

func _process(_delta: float) -> void:
	if not enabled:
		return

	# Небольшое дрожание через смещение текстуры (offset)
	# Это создает эффект "дрожащих рук" без изменения угла
	offset.y = randf_range(-shake_intensity, shake_intensity)
	
	# Мерцание
	if randf() < flicker_chance:
		energy = base_energy * randf_range(0.8, 1.1)
	else:
		energy = lerp(energy, base_energy, 0.1)
