extends "res://scripts/enemy.gd"

## Допуск по X, чтобы считать игрока под собой.
@export var align_threshold: float = 24.0
## Атаковать только если игрок ниже.
@export var attack_requires_below: bool = true
## Агрессия только после звука игрока.
@export var only_sound: bool = false

var _heard_player_sound: bool = false

func _physics_process(_delta: float) -> void:
	if not _should_chase_player():
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

func _should_chase_player() -> bool:
	if not chase_player or _player == null:
		return false
	if only_sound and not _heard_player_sound:
		return false
	return true

func _try_attack_when_aligned() -> void:
	if _player == null:
		return
	if only_sound and not _heard_player_sound:
		return
	if attack_requires_below and _player.global_position.y <= global_position.y:
		return
	if abs(_player.global_position.x - global_position.x) <= align_threshold:
		_attack_player()

func _on_detection_area_body_entered(body: Node) -> void:
	super._on_detection_area_body_entered(body)
	if not only_sound:
		return
	if body.is_in_group("player"):
		_heard_player_sound = false
		_connect_player_sound(body)

func _on_detection_area_body_exited(body: Node) -> void:
	var was_player := body == _player
	super._on_detection_area_body_exited(body)
	if not only_sound:
		return
	_disconnect_player_sound(body)
	if was_player:
		_heard_player_sound = false

func _connect_player_sound(body: Node) -> void:
	if not body.has_signal("player_made_sound"):
		return
	var handler := Callable(self, "_on_player_made_sound")
	if not body.is_connected("player_made_sound", handler):
		body.connect("player_made_sound", handler)

func _disconnect_player_sound(body: Node) -> void:
	if not body.has_signal("player_made_sound"):
		return
	var handler := Callable(self, "_on_player_made_sound")
	if body.is_connected("player_made_sound", handler):
		body.disconnect("player_made_sound", handler)

func _on_player_made_sound() -> void:
	_heard_player_sound = true

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if not _should_chase_player():
		return
	if body.is_in_group("player"):
		_attack_player()
