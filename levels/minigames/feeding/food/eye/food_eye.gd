extends "res://levels/minigames/feeding/food/food_item.gd"

@export_range(0.0, 12.0, 0.1) var pupil_follow_radius: float = 4.5
@export_range(0.0, 1.0, 0.01) var pupil_follow_strength: float = 0.18
@export_range(0.0, 30.0, 0.1) var pupil_follow_speed: float = 14.0
@export_range(0.0, 10.0, 0.1) var pupil_jitter_radius: float = 1.2
@export_range(0.01, 1.0, 0.01) var pupil_jitter_interval_min: float = 0.08
@export_range(0.01, 1.0, 0.01) var pupil_jitter_interval_max: float = 0.22

@onready var _pupil: Sprite2D = $Sprite2D2

var _pupil_base_position: Vector2 = Vector2.ZERO
var _pupil_jitter_offset: Vector2 = Vector2.ZERO
var _pupil_jitter_time_left: float = 0.0


func _ready() -> void:
	super._ready()
	if _pupil != null:
		_pupil_base_position = _pupil.position
	_schedule_next_jitter()


func _process(delta: float) -> void:
	super._process(delta)
	_update_pupil_motion(delta)


func _update_pupil_motion(delta: float) -> void:
	if _pupil == null:
		return

	_pupil_jitter_time_left -= delta
	if _pupil_jitter_time_left <= 0.0:
		_pupil_jitter_offset = _random_offset_in_radius(pupil_jitter_radius)
		_schedule_next_jitter()

	var mouse_local := to_local(get_global_mouse_position())
	var follow_offset := mouse_local * pupil_follow_strength
	if follow_offset.length() > pupil_follow_radius:
		follow_offset = follow_offset.normalized() * pupil_follow_radius

	var target_position := _pupil_base_position + follow_offset + _pupil_jitter_offset
	_pupil.position = _pupil.position.lerp(target_position, clampf(delta * pupil_follow_speed, 0.0, 1.0))


func _schedule_next_jitter() -> void:
	_pupil_jitter_time_left = randf_range(pupil_jitter_interval_min, pupil_jitter_interval_max)


func _random_offset_in_radius(radius: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	return Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.15 * radius, radius)
