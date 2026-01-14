extends "res://scripts/enemy.gd"

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
## Папка с кадрами ходьбы.
@export var walk_frames_path: String = "res://textures/monster_runner_animation_walking"
## Префикс имени кадра (например, ezgif-frame-001.png).
@export var walk_frame_prefix: String = "ezgif-frame-"
## Количество кадров в последовательности.
@export var walk_frame_count: int = 21
## Длительность кадра в секундах.
@export var walk_frame_time: float = 0.08
## Стартовый кадр цикла (1-based).
@export var walk_loop_start_index: int = 1
## Конечный кадр цикла (1-based), -1 = последний кадр.
@export var walk_loop_end_index: int = -1
## Номера кадров (начиная с 1), на которых должен звучать шаг.
## Например: [2, 9] означает, что звук будет на 2-м и 9-м кадре анимации.
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
var _step_player: AudioStreamPlayer2D
var _growl_player: AudioStreamPlayer2D
var _scream_player: AudioStreamPlayer2D
var _wander_timer: float = 0.0
var _wander_dir: float = 1.0
var _wander_moving: bool = false
var _idle_texture: Texture2D = null
var _walk_frames: Array[Texture2D] = []
var _walk_frame_index: int = 0
var _walk_frame_timer: float = 0.0
var _is_walking: bool = false
var _sprite_anim_scale: Vector2 = Vector2.ONE
var _walk_loop_start: int = 0
var _walk_loop_end: int = 0
var _step_frame_lookup: Dictionary = {}
var _facing_dir: float = 1.0

func _ready() -> void:
	super._ready()

	_step_player = AudioStreamPlayer2D.new()
	_step_player.bus = "SFX"
	_step_player.max_polyphony = 4
	_step_player.max_distance = 50000.0
	_step_player.attenuation = 0.0
	add_child(_step_player)
	
	_growl_player = AudioStreamPlayer2D.new()
	_growl_player.bus = "SFX"
	add_child(_growl_player)

	_scream_player = AudioStreamPlayer2D.new()
	_scream_player.bus = "SFX"
	add_child(_scream_player)

	_reset_growl_timer()

	if _sprite:
		_idle_texture = _sprite.texture
		_load_walk_frames()

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

func _play_step_sound() -> void:
	if step_sounds.is_empty():
		return
	_step_player.stream = step_sounds.pick_random()
	_step_player.volume_db = step_volume_db
	_step_player.pitch_scale = randf_range(0.9, 1.1)
	_step_player.play()

func _trigger_step() -> void:
	_play_step_sound()
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

func _load_walk_frames() -> void:
	_walk_frames.clear()
	if walk_frame_count <= 0:
		return

	for i in range(1, walk_frame_count + 1):
		var path := "%s/%s%03d.png" % [walk_frames_path, walk_frame_prefix, i]
		var frame := load(path) as Texture2D
		if frame:
			_walk_frames.append(frame)
		else:
			push_warning("Runner: Отсутствует кадр ходьбы: %s" % path)

	_update_walk_loop_bounds()
	_update_step_frame_lookup()

func _update_walk_loop_bounds() -> void:
	_walk_loop_start = 0
	_walk_loop_end = -1
	if _walk_frames.is_empty():
		return
	var max_index := _walk_frames.size() - 1
	_walk_loop_start = clampi(walk_loop_start_index - 1, 0, max_index)

	var end_index_req := walk_loop_end_index
	if end_index_req < 0:
		_walk_loop_end = max_index
	else:
		_walk_loop_end = clampi(end_index_req - 1, _walk_loop_start, max_index)

func _update_step_frame_lookup() -> void:
	_step_frame_lookup.clear()
	if _walk_frames.is_empty():
		return

	for index in step_frame_indices:
		if index <= 0:
			continue
		var frame_index_0_based := index - 1
		if frame_index_0_based >= 0 and frame_index_0_based < _walk_frames.size():
			_step_frame_lookup[frame_index_0_based] = true
		else:
			push_warning("Runner: Указан кадр шага %d, но всего кадров %d" % [index, _walk_frames.size()])

func _maybe_play_step_for_frame(frame_index: int) -> void:
	if _step_frame_lookup.has(frame_index):
		_trigger_step()

func _calc_texture_scale(texture: Texture2D) -> Vector2:
	if _idle_texture == null or texture == null:
		return Vector2.ONE
	var idle_size := _idle_texture.get_size()
	var tex_size := texture.get_size()
	if idle_size.y <= 0.0 or tex_size.y <= 0.0:
		return Vector2.ONE
	var ratio := idle_size.y / tex_size.y
	return Vector2(ratio, ratio)

func _set_sprite_texture(texture: Texture2D) -> void:
	if _sprite == null or texture == null:
		return
	_sprite.texture = texture
	_sprite_anim_scale = _calc_texture_scale(texture)
	_apply_facing()

func _update_walk_animation(delta: float) -> void:
	if _sprite == null or _walk_frames.is_empty():
		return
	if walk_frame_time <= 0.0:
		return
	if _walk_loop_end < 0:
		return

	var is_moving := velocity.length() > 0.1

	if is_moving:
		if not _is_walking:
			_is_walking = true
			_walk_frame_index = _walk_loop_start
			_walk_frame_timer = 0.0

			_set_sprite_texture(_walk_frames[_walk_frame_index])
			_maybe_play_step_for_frame(_walk_frame_index)

		_walk_frame_timer += delta
		while _walk_frame_timer >= walk_frame_time:
			_walk_frame_timer -= walk_frame_time

			if _walk_frame_index >= _walk_loop_end:
				_walk_frame_index = _walk_loop_start
			else:
				_walk_frame_index += 1

			_set_sprite_texture(_walk_frames[_walk_frame_index])
			_maybe_play_step_for_frame(_walk_frame_index)
	else:
		if _is_walking:
			_is_walking = false
			_walk_frame_timer = 0.0
			_walk_frame_index = _walk_loop_start
			if _idle_texture:
				_set_sprite_texture(_idle_texture)

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

	var base_offset: Vector2
	if camera.has_meta("enemy_step_base_offset"):
		base_offset = camera.get_meta("enemy_step_base_offset")
	else:
		base_offset = camera.offset
		camera.set_meta("enemy_step_base_offset", base_offset)

	var shake = Vector2(
		randf_range(-camera_shake_intensity, camera_shake_intensity),
		randf_range(-camera_shake_intensity, camera_shake_intensity)
	)
	camera.offset = base_offset + shake
	get_tree().create_timer(camera_shake_duration).timeout.connect(func():
		if is_instance_valid(camera):
			var stored_base = base_offset
			if camera.has_meta("enemy_step_base_offset"):
				stored_base = camera.get_meta("enemy_step_base_offset")
			camera.offset = stored_base
	)
