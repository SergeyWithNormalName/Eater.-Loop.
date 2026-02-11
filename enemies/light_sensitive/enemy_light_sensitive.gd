extends "res://enemies/enemy_flashlight_base.gd"

@export_group("Animation")
## Имя анимации простоя.
@export var idle_animation: StringName = &"idle"
## Имя анимации ходьбы.
@export var walk_animation: StringName = &"walk"
## Длительность кадра анимации ходьбы.
@export var walk_frame_time: float = 0.08
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
## Замедление после стана, если фонарик продолжает светить (1.0 = без замедления).
@export_range(1.0, 3.0, 0.1) var flashlight_slow_factor: float = 1.5
## Дистанция отступления при стане.
@export var knockback_distance: float = 60.0
## Скорость отступления при стане.
@export var knockback_speed: float = 120.0

var _stun_timer: float = 0.0
var _stun_cooldown_timer: float = 0.0
var _knockback_remaining: float = 0.0
var _knockback_dir: Vector2 = Vector2.ZERO
var _player_in_hitbox: Node2D = null
var _is_walking: bool = false
var _was_stunned: bool = false
var _lamp_frozen: bool = false
var _animated_sprite: AnimatedSprite2D = null
var _flashlight_anim_active: bool = false
var _lamp_anim_active: bool = false
var _lamp_react_playing: bool = false

const WALK_FRAMES_DIR := "res://enemies/light_sensitive/animations/walking"
const WALK_FRAME_PREFIX := "ezgif-frame-"
const WALK_LOOP_ANIMATION: StringName = &"walk_loop"
const WALK_LOOP_START_FRAME: int = 5
const WALK_LOOP_END_FRAME: int = 22

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
	_setup_walk_animation()
	_set_idle_animation()
	_sync_light_mask_with_player()

func _setup_walk_animation() -> void:
	if _animated_sprite == null:
		return
	if _animated_sprite.sprite_frames == null:
		_animated_sprite.sprite_frames = SpriteFrames.new()
	var frames := _animated_sprite.sprite_frames
	if walk_animation == StringName():
		return
	var frame_numbers := _collect_walk_frame_numbers()
	if frame_numbers.is_empty():
		return
	if frames.has_animation(walk_animation):
		frames.remove_animation(walk_animation)
	frames.add_animation(walk_animation)
	for frame_number in frame_numbers:
		var texture := _load_walk_texture(frame_number)
		if texture != null:
			frames.add_frame(walk_animation, texture)
	if frames.get_frame_count(walk_animation) <= 0:
		frames.remove_animation(walk_animation)
		return
	if walk_frame_time > 0.0:
		frames.set_animation_speed(walk_animation, 1.0 / walk_frame_time)
	frames.set_animation_loop(walk_animation, false)
	_setup_walk_loop_animation(frames, frame_numbers)

func _setup_walk_loop_animation(frames: SpriteFrames, frame_numbers: Array[int]) -> void:
	if frames.has_animation(WALK_LOOP_ANIMATION):
		frames.remove_animation(WALK_LOOP_ANIMATION)
	if frame_numbers.is_empty():
		return
	var loop_numbers: Array[int] = []
	for frame_number in frame_numbers:
		if frame_number >= WALK_LOOP_START_FRAME and frame_number <= WALK_LOOP_END_FRAME:
			loop_numbers.append(frame_number)
	if loop_numbers.is_empty():
		loop_numbers = frame_numbers.duplicate()
	frames.add_animation(WALK_LOOP_ANIMATION)
	for frame_number in loop_numbers:
		var texture := _load_walk_texture(frame_number)
		if texture != null:
			frames.add_frame(WALK_LOOP_ANIMATION, texture)
	if frames.get_frame_count(WALK_LOOP_ANIMATION) <= 0:
		frames.remove_animation(WALK_LOOP_ANIMATION)
		return
	if walk_frame_time > 0.0:
		frames.set_animation_speed(WALK_LOOP_ANIMATION, 1.0 / walk_frame_time)
	frames.set_animation_loop(WALK_LOOP_ANIMATION, true)

func _collect_walk_frame_numbers() -> Array[int]:
	var numbers: Array[int] = []
	var dir := DirAccess.open(WALK_FRAMES_DIR)
	if dir == null:
		return numbers
	for file_name in dir.get_files():
		if not file_name.ends_with(".png"):
			continue
		var frame_number := _extract_walk_frame_number(file_name)
		if frame_number < 0:
			continue
		numbers.append(frame_number)
	numbers.sort()
	return numbers

func _extract_walk_frame_number(file_name: String) -> int:
	if not file_name.begins_with(WALK_FRAME_PREFIX):
		return -1
	var suffix := file_name.trim_prefix(WALK_FRAME_PREFIX)
	if not suffix.ends_with(".png"):
		return -1
	var number_str := suffix.trim_suffix(".png")
	if number_str.is_empty() or not number_str.is_valid_int():
		return -1
	return int(number_str)

func _load_walk_texture(frame_number: int) -> Texture2D:
	var path := "%s/%s%03d.png" % [WALK_FRAMES_DIR, WALK_FRAME_PREFIX, frame_number]
	return load(path) as Texture2D

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
	if flashlight_hit and _try_stun():
		_update_stun_motion(delta)
		return

	_apply_chase_motion(flashlight_hit)

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

func _update_stun_motion(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

func _apply_chase_motion(flashlight_hit: bool) -> void:
	if not chase_player or _player == null:
		velocity = Vector2.ZERO
		_update_motion_animation()
		return

	var delta_pos := _player.global_position - global_position
	if abs(delta_pos.x) < 1.0:
		velocity = Vector2.ZERO
	else:
		var speed_multiplier := 1.0
		if flashlight_hit and _stun_cooldown_timer > 0.0:
			speed_multiplier = max(1.0, flashlight_slow_factor)
		var applied_speed := speed / speed_multiplier
		velocity = Vector2(sign(delta_pos.x) * applied_speed, 0.0)

	move_and_slide()
	_update_facing_from_velocity()
	_update_motion_animation()

func _update_motion_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if _lamp_anim_active or _flashlight_anim_active:
		_is_walking = false
		return
	var moving := absf(velocity.x) > 0.1
	if moving:
		if not _is_walking:
			_is_walking = true
			_start_walk_animation()
			return
		if _animated_sprite.animation != walk_animation and _animated_sprite.animation != WALK_LOOP_ANIMATION:
			_start_walk_animation()
		return
	_is_walking = false
	_set_idle_animation()

func _start_walk_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if walk_animation == StringName() or not _animated_sprite.sprite_frames.has_animation(walk_animation):
		_set_idle_animation()
		return
	if _animated_sprite.animation != walk_animation:
		_animated_sprite.play(walk_animation)
	_animated_sprite.frame = 0
	_animated_sprite.play()

func _start_walk_loop_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if _animated_sprite.sprite_frames.has_animation(WALK_LOOP_ANIMATION):
		if _animated_sprite.animation != WALK_LOOP_ANIMATION:
			_animated_sprite.play(WALK_LOOP_ANIMATION)
		_animated_sprite.play()
		return
	if walk_animation != StringName() and _animated_sprite.sprite_frames.has_animation(walk_animation):
		_animated_sprite.play(walk_animation)

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
	if _animated_sprite == null:
		return
	if _lamp_anim_active and _animated_sprite.animation == lamp_react_animation:
		_start_lamp_stan_animation()
		return
	if _is_walking and not _lamp_anim_active and not _flashlight_anim_active and _animated_sprite.animation == walk_animation:
		_start_walk_loop_animation()

func _set_idle_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if idle_animation != StringName() and _animated_sprite.sprite_frames.has_animation(idle_animation):
		if _animated_sprite.animation != idle_animation:
			_animated_sprite.play(idle_animation)
		return
	_animated_sprite.stop()
	_animated_sprite.frame = 0
