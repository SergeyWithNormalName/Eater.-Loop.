extends "res://enemies/enemy.gd"

@export_group("Audio")
## Звуки шагов.
@export var step_sounds: Array[AudioStream] = []
## Громкость шагов в дБ.
@export var step_volume_db: float = -12.0
## Звуки рычания.
@export var growl_sounds: Array[AudioStream] = []
## Звук крика при обнаружении игрока.
@export var scream_sound: AudioStream
## Громкость крика в дБ.
@export var scream_volume_db: float = -4.0
## Минимальный интервал рычания.
@export var growl_interval_min: float = 2.5
## Максимальный интервал рычания.
@export var growl_interval_max: float = 5.0
## Громкость рычания в дБ.
@export var growl_volume_db: float = -6.0
## Минимальный питч рычания.
@export var growl_pitch_min: float = 0.95
## Максимальный питч рычания.
@export var growl_pitch_max: float = 1.05

@export_group("Walk Animation")
## Имя анимации ходьбы в AnimatedSprite2D.
@export var walk_animation: StringName = &"walk"
## Имя анимации покоя (если нет, будет стоять на первом кадре walk).
@export var idle_animation: StringName = &"idle"
## Длительность кадра в секундах.
@export var walk_frame_time: float = 0.08
## Стартовый кадр цикла (1-based).
@export var walk_loop_start_index: int = 1
## Конечный кадр цикла (1-based), -1 = последний кадр.
@export var walk_loop_end_index: int = -1
## Номера кадров (начиная с 1), на которых должен звучать шаг.
@export var step_frame_indices: Array[int] = [2, 9]

@export_group("Idle Wander")
## Разрешить бродяжничать вне зоны обнаружения.
@export var allow_idle_wander: bool = true
## Скорость бродяжничества.
@export var wander_speed: float = 40.0
## Минимальная длительность шага.
@export var wander_walk_time_min: float = 0.4
## Максимальная длительность шага.
@export var wander_walk_time_max: float = 1.2
## Минимальная пауза между шагами.
@export var wander_pause_time_min: float = 1.0
## Максимальная пауза между шагами.
@export var wander_pause_time_max: float = 2.5

@export_group("Camera Shake")
## Сила тряски камеры от шагов.
@export var camera_shake_intensity: float = 3.0
## Длительность тряски камеры.
@export var camera_shake_duration: float = 0.08

var _growl_timer: float = 0.0
var _growl_player: AudioStreamPlayer2D
var _scream_player: AudioStreamPlayer2D
var _wander_timer: float = 0.0
var _wander_dir: float = 1.0
var _wander_moving: bool = false
var _idle_texture: Texture2D = null
var _is_walking: bool = false
var _sprite_anim_scale: Vector2 = Vector2.ONE
var _walk_loop_start: int = 0
var _walk_loop_end: int = 0
var _facing_dir: float = 1.0
var _adjusting_frame: bool = false
var _animated_sprite: AnimatedSprite2D = null
var _step_audio: StepAudioComponent = null

func _ready() -> void:
	super._ready()

	_growl_player = AudioStreamPlayer2D.new()
	_growl_player.bus = "Sounds"
	add_child(_growl_player)

	_scream_player = AudioStreamPlayer2D.new()
	_scream_player.bus = "Sounds"
	add_child(_scream_player)

	_reset_growl_timer()

	_animated_sprite = _sprite as AnimatedSprite2D
	if _animated_sprite == null:
		_animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if _animated_sprite:
			_sprite = _animated_sprite
	if _animated_sprite:
		_animated_sprite.frame_changed.connect(_on_sprite_frame_changed)
		_step_audio = _resolve_step_audio_component()
		if _step_audio:
			_step_audio.configure(step_sounds, step_volume_db, step_frame_indices, walk_animation)
			_step_audio.step_triggered.connect(_on_step_triggered)
		_setup_animations()

func _physics_process(delta: float) -> void:
	var is_chasing := chase_player and _player != null
	if is_chasing:
		var offset = _player.global_position - global_position
		if abs(offset.x) < 1.0:
			velocity = Vector2.ZERO
		else:
			velocity = Vector2(sign(offset.x) * speed, 0.0)
	else:
		_update_idle_wander(delta)

	move_and_slide()
	_update_facing_from_velocity()
	_update_walk_animation(delta)
	_update_growls(delta)

func _trigger_step() -> void:
	_shake_camera()

func _update_growls(delta: float) -> void:
	if growl_sounds.is_empty():
		return
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_play_growl()
		_reset_growl_timer()

func _play_growl() -> void:
	_growl_player.stream = growl_sounds.pick_random()
	_growl_player.volume_db = growl_volume_db
	_growl_player.pitch_scale = randf_range(growl_pitch_min, growl_pitch_max)
	_growl_player.play()

func _play_scream() -> void:
	if scream_sound == null:
		return
	_scream_player.stream = scream_sound
	_scream_player.volume_db = scream_volume_db
	_scream_player.pitch_scale = randf_range(0.95, 1.05)
	_scream_player.play()

func _reset_growl_timer() -> void:
	var min_val = max(0.1, growl_interval_min)
	var max_val = max(min_val, growl_interval_max)
	_growl_timer = randf_range(min_val, max_val)

func _update_idle_wander(delta: float) -> void:
	if not allow_idle_wander:
		velocity = Vector2.ZERO
		_wander_moving = false
		return

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		if _wander_moving:
			_wander_moving = false
			_wander_timer = _rand_range_clamped(wander_pause_time_min, wander_pause_time_max)
		else:
			_wander_moving = true
			_wander_dir = -1.0 if randf() < 0.5 else 1.0
			_wander_timer = _rand_range_clamped(wander_walk_time_min, wander_walk_time_max)

	if _wander_moving:
		velocity = Vector2(_wander_dir * wander_speed, 0.0)
	else:
		velocity = Vector2.ZERO

func _rand_range_clamped(min_val: float, max_val: float) -> float:
	var min_safe = max(0.05, min_val)
	var max_safe = max(min_safe, max_val)
	return randf_range(min_safe, max_safe)

func _apply_facing() -> void:
	if _sprite == null:
		return
	var x_scale = absf(_sprite_base_scale.x) * -_facing_dir * _sprite_anim_scale.x
	var y_scale = _sprite_base_scale.y * _sprite_anim_scale.y
	_sprite.scale = Vector2(x_scale, y_scale)

func _update_facing_from_velocity() -> void:
	if _sprite == null:
		return
	if abs(velocity.x) < 0.1:
		return
	_facing_dir = sign(velocity.x)
	_apply_facing()
func _setup_animations() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	_idle_texture = _get_idle_texture()
	_update_walk_loop_bounds()
	if walk_frame_time > 0.0 and _animated_sprite.sprite_frames.has_animation(walk_animation):
		_animated_sprite.sprite_frames.set_animation_speed(walk_animation, 1.0 / walk_frame_time)

func _get_idle_texture() -> Texture2D:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return null
	if idle_animation != StringName() and _animated_sprite.sprite_frames.has_animation(idle_animation):
		return _animated_sprite.sprite_frames.get_frame_texture(idle_animation, 0)
	if _animated_sprite.sprite_frames.has_animation(walk_animation):
		return _animated_sprite.sprite_frames.get_frame_texture(walk_animation, 0)
	return null

func _update_walk_loop_bounds() -> void:
	_walk_loop_start = 0
	_walk_loop_end = -1
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation(walk_animation):
		return
	var max_index := _animated_sprite.sprite_frames.get_frame_count(walk_animation) - 1
	if max_index < 0:
		return
	_walk_loop_start = clampi(walk_loop_start_index - 1, 0, max_index)
	var end_index_req := walk_loop_end_index
	if end_index_req < 0:
		_walk_loop_end = max_index
	else:
		_walk_loop_end = clampi(end_index_req - 1, _walk_loop_start, max_index)

func _calc_texture_scale(texture: Texture2D) -> Vector2:
	if _idle_texture == null or texture == null:
		return Vector2.ONE
	var idle_size := _idle_texture.get_size()
	var tex_size := texture.get_size()
	if idle_size.y <= 0.0 or tex_size.y <= 0.0:
		return Vector2.ONE
	var ratio := idle_size.y / tex_size.y
	return Vector2(ratio, ratio)

func _update_walk_animation(_delta: float) -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	var is_moving := velocity.length() > 0.1

	if is_moving:
		if not _is_walking:
			_is_walking = true
			_start_walk_animation()
	else:
		if _is_walking:
			_is_walking = false
			_start_idle_animation()

func _start_walk_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if not _animated_sprite.sprite_frames.has_animation(walk_animation):
		return
	if _animated_sprite.animation != walk_animation:
		_animated_sprite.play(walk_animation)
	_animated_sprite.frame = _walk_loop_start
	_animated_sprite.play()
	_enforce_walk_loop_range()

func _start_idle_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if idle_animation != StringName() and _animated_sprite.sprite_frames.has_animation(idle_animation):
		if _animated_sprite.animation != idle_animation:
			_animated_sprite.play(idle_animation)
		return
	_animated_sprite.stop()
	_animated_sprite.frame = 0
	_update_sprite_scale_for_current_frame()

func _on_sprite_frame_changed() -> void:
	if _animated_sprite == null:
		return
	_update_sprite_scale_for_current_frame()
	_enforce_walk_loop_range()

func _update_sprite_scale_for_current_frame() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	var texture := _animated_sprite.sprite_frames.get_frame_texture(_animated_sprite.animation, _animated_sprite.frame)
	_sprite_anim_scale = _calc_texture_scale(texture)
	_apply_facing()

func _enforce_walk_loop_range() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	if _animated_sprite.animation != walk_animation:
		return
	if _walk_loop_end < 0:
		return
	if _adjusting_frame:
		return
	if _animated_sprite.frame < _walk_loop_start or _animated_sprite.frame > _walk_loop_end:
		_adjusting_frame = true
		_animated_sprite.frame = _walk_loop_start
		_adjusting_frame = false

func _on_step_triggered(_frame_index: int, _animation_name: StringName) -> void:
	_trigger_step()

func _resolve_step_audio_component() -> StepAudioComponent:
	if _animated_sprite and _animated_sprite.has_node("StepAudioComponent"):
		return _animated_sprite.get_node("StepAudioComponent") as StepAudioComponent
	if has_node("StepAudioComponent"):
		return get_node("StepAudioComponent") as StepAudioComponent
	return null

func _on_detection_area_body_entered(body: Node) -> void:
	super._on_detection_area_body_entered(body)
	if body.is_in_group("player"):
		_play_scream()

func _shake_camera() -> void:
	if camera_shake_intensity <= 0.0 or camera_shake_duration <= 0.0:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var base_offset: Vector2 = camera.offset
	if camera.has_meta("enemy_step_base_offset"):
		var meta_value: Variant = camera.get_meta("enemy_step_base_offset")
		if meta_value is Vector2:
			base_offset = meta_value
		else:
			camera.set_meta("enemy_step_base_offset", base_offset)
	else:
		camera.set_meta("enemy_step_base_offset", base_offset)

	var shake = Vector2(
		randf_range(-camera_shake_intensity, camera_shake_intensity),
		randf_range(-camera_shake_intensity, camera_shake_intensity)
	)
	camera.offset = base_offset + shake
	var camera_ref: WeakRef = weakref(camera)
	get_tree().create_timer(camera_shake_duration).timeout.connect(_restore_camera_offset.bind(camera_ref, base_offset))

func _restore_camera_offset(camera_ref: WeakRef, base_offset: Vector2) -> void:
	if camera_ref == null:
		return
	var camera: Camera2D = camera_ref.get_ref() as Camera2D
	if camera == null:
		return
	var stored_base: Vector2 = base_offset
	if camera.has_meta("enemy_step_base_offset"):
		var meta_value: Variant = camera.get_meta("enemy_step_base_offset")
		if meta_value is Vector2:
			stored_base = meta_value
	camera.offset = stored_base
