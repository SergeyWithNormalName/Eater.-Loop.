extends "res://scripts/enemy.gd"

@export_group("Audio")
## Звуки шагов.
@export var step_sounds: Array[AudioStream] = []
## Интервал шагов при бродяжничестве.
@export var step_interval: float = 0.45
## Интервал шагов при преследовании.
@export var step_interval_chase: float = 0.2
## Громкость шагов в дБ.
@export var step_volume_db: float = -12.0
## Звуки рычания.
@export var growl_sounds: Array[AudioStream] = []
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

var _step_timer: float = 0.0
var _growl_timer: float = 0.0
var _step_player: AudioStreamPlayer2D
var _growl_player: AudioStreamPlayer2D
var _wander_timer: float = 0.0
var _wander_dir: float = 1.0
var _wander_moving: bool = false

func _ready() -> void:
	_step_player = AudioStreamPlayer2D.new()
	add_child(_step_player)

	_growl_player = AudioStreamPlayer2D.new()
	add_child(_growl_player)
	_reset_growl_timer()

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
	_update_steps(delta, is_chasing)
	_update_growls(delta)

func _update_steps(delta: float, is_chasing: bool) -> void:
	if velocity.length() > 0.1:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_play_step()
			_step_timer = _get_step_interval(is_chasing)
	else:
		_step_timer = 0.05

func _play_step() -> void:
	if step_sounds.is_empty():
		return
	_step_player.stream = step_sounds.pick_random()
	_step_player.volume_db = step_volume_db
	_step_player.pitch_scale = randf_range(0.9, 1.1)
	_step_player.play()
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

func _get_step_interval(is_chasing: bool) -> float:
	var interval = step_interval_chase if is_chasing else step_interval
	return max(0.05, interval)

func _rand_range_clamped(min_val: float, max_val: float) -> float:
	var min_safe = max(0.05, min_val)
	var max_safe = max(min_safe, max_val)
	return randf_range(min_safe, max_safe)

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
