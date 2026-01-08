extends "res://scripts/enemy.gd"

## Допуск по X, чтобы считать игрока под собой.
@export var align_threshold: float = 24.0
## Атаковать только если игрок ниже.
@export var attack_requires_below: bool = true

func _physics_process(_delta: float) -> void:
	if not chase_player or _player == null:
		velocity = Vector2.ZERO
		return

	var offset_x = _player.global_position.x - global_position.x
	if abs(offset_x) > align_threshold:
		velocity = Vector2(sign(offset_x) * speed, 0.0)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_update_facing_from_velocity()
	_try_attack_when_aligned()

func _try_attack_when_aligned() -> void:
	if _player == null:
		return
	if attack_requires_below and _player.global_position.y <= global_position.y:
		return
	if abs(_player.global_position.x - global_position.x) <= align_threshold:
		_attack_player()
