extends "res://enemies/enemy_flashlight_base.gd"

@export_group("Animation")
## Имя анимации простоя.
@export var idle_animation: StringName = &"idle"
## Имя анимации реакции на фонарик.
@export var flashlight_animation: StringName = &"flashlight"
## Имя анимации реакции на свет лампы.
@export var lamp_react_animation: StringName = &"lamp_react"
## Имя анимации стана от лампы.
@export var lamp_stan_animation: StringName = &"lamp_stan"

@export_group("Stun")
## Длительность стана от света.
@export var stun_duration: float = 2.0
## Перезарядка стана.
@export var stun_cooldown: float = 6.0
## Дистанция отступления при стане.
@export var knockback_distance: float = 60.0
## Скорость отступления при стане.
@export var knockback_speed: float = 120.0

var _stun_timer: float = 0.0
var _stun_cooldown_timer: float = 0.0
var _knockback_remaining: float = 0.0
var _knockback_dir: Vector2 = Vector2.ZERO
var _player_in_hitbox: Node2D = null
var _was_stunned: bool = false
var _lamp_frozen: bool = false
var _animated_sprite: AnimatedSprite2D = null
var _flashlight_anim_active: bool = false
var _lamp_anim_active: bool = false
var _lamp_react_playing: bool = false

func _ready() -> void:
	super._ready()
	_animated_sprite = _sprite as AnimatedSprite2D
	if _animated_sprite == null:
		_animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if _animated_sprite != null:
			_sprite = _animated_sprite
	if _animated_sprite != null:
		if not _animated_sprite.animation_finished.is_connected(_on_animation_finished):
			_animated_sprite.animation_finished.connect(_on_animation_finished)
	_set_idle_animation()
	_sync_light_mask_with_player()

func _sync_light_mask_with_player() -> void:
	var player := _player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var player_sprite := player.get_node_or_null("Pivot/AnimatedSprite2D") as CanvasItem
	if player_sprite == null:
		player_sprite = player.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if player_sprite == null:
		player_sprite = player.get_node_or_null("Sprite2D") as CanvasItem
	var mask := 0
	if player_sprite != null:
		mask = player_sprite.light_mask
	else:
		var player_item := player as CanvasItem
		if player_item == null:
			return
		mask = player_item.light_mask
	light_mask = mask
	var sprite_item := _sprite as CanvasItem
	if sprite_item != null:
		sprite_item.light_mask = mask
	if _animated_sprite != null:
		_animated_sprite.light_mask = mask

func _physics_process(delta: float) -> void:
	_update_stun_timers(delta)
	var flashlight_hit := _is_flashlight_cone_hitting()
	if _flashlight_anim_active and _stun_timer <= 0.0:
		_stop_flashlight_stun_animation()
	var lamp_frozen_now := _update_lamp_freeze_state()
	var stunned_now := lamp_frozen_now or _stun_timer > 0.0
	if _was_stunned and not stunned_now:
		_try_attack_if_in_hitbox()
	_was_stunned = stunned_now
	if lamp_frozen_now:
		_apply_lamp_freeze_motion()
		return
	if _stun_timer > 0.0:
		_update_stun_motion(delta)
		return

	super._physics_process(delta)
	if flashlight_hit:
		_try_stun()

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_hitbox = body
	if _update_lamp_freeze_state():
		return
	if _is_flashlight_cone_hitting():
		if _try_stun():
			return
	if _stun_timer > 0.0:
		return
	super._on_hitbox_area_body_entered(body)

func _on_hitbox_area_body_exited(body: Node2D) -> void:
	if body == _player_in_hitbox:
		_player_in_hitbox = null
	super._on_hitbox_area_body_exited(body)

func _try_stun() -> bool:
	if _lamp_frozen:
		return false
	if _stun_timer > 0.0 or _stun_cooldown_timer > 0.0:
		return false
	_stun_timer = max(0.0, stun_duration)
	_stun_cooldown_timer = max(0.0, stun_cooldown)
	if _stun_timer > 0.0:
		_start_flashlight_stun_animation()
	_knockback_remaining = 0.0
	_knockback_dir = Vector2.ZERO
	return _stun_timer > 0.0

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
	if _lamp_frozen or _stun_timer > 0.0:
		return
	if _player_in_hitbox != null and is_instance_valid(_player_in_hitbox):
		_attack_player()

func _update_lamp_freeze_state() -> bool:
	var was_frozen := _lamp_frozen
	_lamp_frozen = _is_lamp_light_hitting()
	if _lamp_frozen != was_frozen:
		_set_chase_music_suppressed(_lamp_frozen)
		if _lamp_frozen:
			_start_lamp_animation()
		else:
			_stop_lamp_animation()
	return _lamp_frozen

func _apply_lamp_freeze_motion() -> void:
	velocity = Vector2.ZERO
	move_and_slide()

func _start_flashlight_stun_animation() -> void:
	_play_flashlight_animation_for(stun_duration)

func _play_flashlight_animation_for(duration: float) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation(flashlight_animation):
		return
	_flashlight_anim_active = true
	var frames := _animated_sprite.sprite_frames.get_frame_count(flashlight_animation)
	if duration > 0.0 and frames > 0:
		var total_duration := 0.0
		for index in range(frames):
			total_duration += _animated_sprite.sprite_frames.get_frame_duration(flashlight_animation, index)
		if total_duration > 0.0:
			_animated_sprite.sprite_frames.set_animation_speed(flashlight_animation, total_duration / duration)
	if _animated_sprite.animation != flashlight_animation:
		_animated_sprite.play(flashlight_animation)
	_animated_sprite.frame = 0
	_animated_sprite.play()

func _stop_flashlight_stun_animation() -> void:
	_flashlight_anim_active = false
	if _lamp_anim_active:
		return
	_set_idle_animation()

func _start_lamp_animation() -> void:
	if _lamp_anim_active:
		return
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	_lamp_anim_active = true
	_stop_flashlight_stun_animation()
	if _animated_sprite.sprite_frames.has_animation(lamp_react_animation):
		_lamp_react_playing = true
		if _animated_sprite.animation != lamp_react_animation:
			_animated_sprite.play(lamp_react_animation)
		_animated_sprite.frame = 0
		_animated_sprite.play()
		return
	_start_lamp_stan_animation()

func _stop_lamp_animation() -> void:
	_lamp_anim_active = false
	_lamp_react_playing = false
	if _stun_timer > 0.0:
		_play_flashlight_animation_for(_stun_timer)
		return
	_set_idle_animation()

func _start_lamp_stan_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation(lamp_stan_animation):
		return
	_lamp_react_playing = false
	if _animated_sprite.animation != lamp_stan_animation:
		_animated_sprite.play(lamp_stan_animation)
	_animated_sprite.play()

func _on_animation_finished() -> void:
	if not _lamp_anim_active:
		return
	if _animated_sprite == null:
		return
	if _animated_sprite.animation == lamp_react_animation:
		_start_lamp_stan_animation()

func _set_idle_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if idle_animation != StringName() and _animated_sprite.sprite_frames.has_animation(idle_animation):
		if _animated_sprite.animation != idle_animation:
			_animated_sprite.play(idle_animation)
		return
	_animated_sprite.stop()
	_animated_sprite.frame = 0
