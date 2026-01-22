extends Node

class_name StepAudioComponent

signal step_triggered(frame_index: int, animation_name: StringName)

@export var sprite_path: NodePath
@export var step_sounds: Array[AudioStream] = []
@export var step_volume_db: float = -10.0
@export var step_frame_indices: Array[int] = [2, 9]
@export var animation_name: StringName = &"walk"
@export var pitch_min: float = 0.95
@export var pitch_max: float = 1.05

var _sprite: AnimatedSprite2D
var _step_player: AudioStreamPlayer
var _step_frame_lookup: Dictionary = {}

func _ready() -> void:
	_step_player = AudioStreamPlayer.new()
	_step_player.bus = "Sounds"
	_step_player.max_polyphony = 4
	add_child(_step_player)

	_resolve_sprite()
	_update_step_frame_lookup()

	if _sprite:
		_sprite.frame_changed.connect(_on_sprite_frame_changed)
		_warn_on_invalid_step_frames()

func configure(
		new_step_sounds: Array[AudioStream],
		new_volume_db: float,
		new_step_frame_indices: Array[int],
		new_animation_name: StringName
	) -> void:
	step_sounds = new_step_sounds
	step_volume_db = new_volume_db
	step_frame_indices = new_step_frame_indices
	animation_name = new_animation_name
	_update_step_frame_lookup()
	_warn_on_invalid_step_frames()

func _resolve_sprite() -> void:
	if sprite_path != NodePath():
		_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
		if _sprite:
			return

	var parent_sprite := get_parent() as AnimatedSprite2D
	if parent_sprite:
		_sprite = parent_sprite
		return

	var owner_sprite := get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if owner_sprite:
		_sprite = owner_sprite
		return

	push_warning("StepAudioComponent: AnimatedSprite2D не найден.")

func _update_step_frame_lookup() -> void:
	_step_frame_lookup.clear()
	for index in step_frame_indices:
		if index <= 0:
			continue
		_step_frame_lookup[index - 1] = true

func _warn_on_invalid_step_frames() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if animation_name == StringName():
		return
	if not _sprite.sprite_frames.has_animation(animation_name):
		return
	var total_frames := _sprite.sprite_frames.get_frame_count(animation_name)
	for index in step_frame_indices:
		if index <= 0:
			continue
		if index > total_frames:
			push_warning("StepAudioComponent: Указан кадр шага %d, но всего кадров %d." % [index, total_frames])

func _on_sprite_frame_changed() -> void:
	if _sprite == null:
		return
	if animation_name != StringName() and _sprite.animation != animation_name:
		return
	var frame_index := _sprite.frame
	if _step_frame_lookup.has(frame_index):
		_play_step_sound()
		step_triggered.emit(frame_index, _sprite.animation)

func _play_step_sound() -> void:
	if step_sounds.is_empty():
		return
	_step_player.stream = step_sounds.pick_random()
	_step_player.volume_db = step_volume_db
	_step_player.pitch_scale = randf_range(pitch_min, pitch_max)
	_step_player.play()
