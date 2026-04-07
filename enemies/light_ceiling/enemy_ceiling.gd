extends "res://enemies/enemy.gd"

## Допуск по X, чтобы считать игрока под собой.
@export var align_threshold: float = 24.0
## Атаковать только если игрок ниже.
@export var attack_requires_below: bool = true
## Агрессия только после звука игрока.
@export var only_sound: bool = false

var _heard_player_sound: bool = false
var _lamp_frozen: bool = false

func _physics_process(_delta: float) -> void:
	if _is_player_busy_with_minigame():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _apply_lamp_freeze():
		return
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
	if body.is_in_group(GroupNames.PLAYER):
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
	if _is_player_busy_with_minigame():
		return
	if _lamp_frozen:
		return
	if not _should_chase_player():
		return
	if body.is_in_group(GroupNames.PLAYER):
		_attack_player()

func _apply_lamp_freeze() -> bool:
	var was_frozen := _lamp_frozen
	_lamp_frozen = _is_lamp_light_hitting()
	if _lamp_frozen != was_frozen:
		_set_chase_music_suppressed(_lamp_frozen)
	if not _lamp_frozen:
		return false
	velocity = Vector2.ZERO
	move_and_slide()
	return true

func _is_lamp_light_hitting() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for light_source in tree.get_nodes_in_group(GroupNames.REACTIVE_LIGHT_SOURCE):
		if light_source == null or not is_instance_valid(light_source):
			continue
		if not light_source.has_method("is_point_lit"):
			continue
		if bool(light_source.call("is_point_lit", global_position)):
			return true
	return false

func capture_checkpoint_state() -> Dictionary:
	var state := super.capture_checkpoint_state()
	state["heard_player_sound"] = _heard_player_sound
	state["lamp_frozen"] = _lamp_frozen
	return state

func apply_checkpoint_state(state: Dictionary) -> void:
	super.apply_checkpoint_state(state)
	_heard_player_sound = bool(state.get("heard_player_sound", _heard_player_sound))
	_lamp_frozen = bool(state.get("lamp_frozen", _lamp_frozen))
