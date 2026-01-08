extends "res://scripts/enemies/enemy_flashlight_base.gd"

@export_group("Stun")
@export var stun_duration: float = 2.0
@export var stun_cooldown: float = 6.0
@export var knockback_distance: float = 60.0
@export var knockback_speed: float = 120.0

var _stun_timer: float = 0.0
var _stun_cooldown_timer: float = 0.0
var _knockback_remaining: float = 0.0
var _knockback_dir: Vector2 = Vector2.ZERO
var _player_in_hitbox: Node2D = null
var _was_stunned: bool = false

func _physics_process(delta: float) -> void:
	_update_stun_timers(delta)
	var stunned_now := _stun_timer > 0.0
	if _was_stunned and not stunned_now:
		_try_attack_if_in_hitbox()
	_was_stunned = stunned_now
	if _stun_timer > 0.0:
		_update_stun_motion(delta)
		return

	super._physics_process(delta)
	if _is_flashlight_hitting():
		_try_stun()

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_hitbox = body
	if _is_flashlight_hitting():
		_try_stun()
		return
	if _stun_timer > 0.0:
		return
	super._on_hitbox_area_body_entered(body)

func _on_hitbox_area_body_exited(body: Node2D) -> void:
	if body == _player_in_hitbox:
		_player_in_hitbox = null
	super._on_hitbox_area_body_exited(body)

func _try_stun() -> void:
	if _stun_timer > 0.0 or _stun_cooldown_timer > 0.0:
		return
	_stun_timer = max(0.0, stun_duration)
	_stun_cooldown_timer = max(0.0, stun_cooldown)
	_start_knockback()

func _start_knockback() -> void:
	_knockback_remaining = max(0.0, knockback_distance)
	if _knockback_remaining <= 0.0:
		_knockback_dir = Vector2.ZERO
		return
	if _player != null:
		_knockback_dir = Vector2(sign(global_position.x - _player.global_position.x), 0.0)
	else:
		_knockback_dir = Vector2.LEFT

func _update_stun_motion(delta: float) -> void:
	if _knockback_remaining > 0.0 and knockback_speed > 0.0:
		velocity = _knockback_dir * knockback_speed
		var step = knockback_speed * delta
		_knockback_remaining = max(0.0, _knockback_remaining - step)
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _update_stun_timers(delta: float) -> void:
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)
	if _stun_cooldown_timer > 0.0:
		_stun_cooldown_timer = max(0.0, _stun_cooldown_timer - delta)

func _try_attack_if_in_hitbox() -> void:
	if _stun_timer > 0.0:
		return
	if _player_in_hitbox != null and is_instance_valid(_player_in_hitbox):
		_attack_player()
