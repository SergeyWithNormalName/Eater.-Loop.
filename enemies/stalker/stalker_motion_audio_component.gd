extends Node

class_name StalkerMotionAudioComponent

signal step_triggered(frame_index: int, animation_name: StringName)
signal scrape_triggered(frame_index: int, animation_name: StringName)
signal motion_event_triggered(event_name: StringName, frame_index: int, animation_name: StringName)

@export var sprite_path: NodePath

@export_group("General")
@export var audio_bus: StringName = &"Sounds"
@export var max_polyphony: int = 4

@export_group("Step")
@export var step_animation_name: StringName = &"walk"
@export var step_frame_indices: Array[int] = [2, 9, 14, 20]
@export var step_sounds: Array[AudioStream] = []
@export var step_volume_db: float = -10.0
@export var step_pitch_min: float = 0.95
@export var step_pitch_max: float = 1.05

@export_group("Scrape")
@export var scrape_animation_name: StringName = &"walk"
@export var scrape_frame_indices: Array[int] = [4, 11, 17, 22]
@export var scrape_sounds: Array[AudioStream] = []
@export var scrape_volume_db: float = -8.0
@export var scrape_pitch_min: float = 0.95
@export var scrape_pitch_max: float = 1.05

var _sprite: AnimatedSprite2D = null
var _step_player: AudioStreamPlayer
var _scrape_player: AudioStreamPlayer

func _ready() -> void:
	_step_player = AudioStreamPlayer.new()
	_step_player.bus = audio_bus
	_step_player.max_polyphony = max(1, max_polyphony)
	add_child(_step_player)

	_scrape_player = AudioStreamPlayer.new()
	_scrape_player.bus = audio_bus
	_scrape_player.max_polyphony = max(1, max_polyphony)
	add_child(_scrape_player)

	_resolve_sprite()
	_set_sprite(_sprite)
	refresh_configuration()

func configure_step_track(
		new_sounds: Array[AudioStream],
		new_volume_db: float,
		new_frame_indices: Array[int],
		new_animation_name: StringName
	) -> void:
	step_sounds = new_sounds
	step_volume_db = new_volume_db
	step_frame_indices = new_frame_indices
	step_animation_name = new_animation_name
	refresh_configuration()

func configure_scrape_track(
		new_sounds: Array[AudioStream],
		new_volume_db: float,
		new_frame_indices: Array[int],
		new_animation_name: StringName
	) -> void:
	scrape_sounds = new_sounds
	scrape_volume_db = new_volume_db
	scrape_frame_indices = new_frame_indices
	scrape_animation_name = new_animation_name
	refresh_configuration()

func set_sprite(sprite: AnimatedSprite2D) -> void:
	_set_sprite(sprite)
	refresh_configuration()

func _resolve_sprite() -> void:
	if sprite_path != NodePath():
		_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
		if _sprite != null:
			return

	var parent_sprite := get_parent() as AnimatedSprite2D
	if parent_sprite != null:
		_sprite = parent_sprite
		return

	var owner_sprite := get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if owner_sprite != null:
		_sprite = owner_sprite
		return

	push_warning("StalkerMotionAudioComponent: AnimatedSprite2D не найден.")

func refresh_configuration() -> void:
	_warn_on_invalid_frames(step_animation_name, step_frame_indices, "step")
	_warn_on_invalid_frames(scrape_animation_name, scrape_frame_indices, "scrape")

func _set_sprite(sprite: AnimatedSprite2D) -> void:
	if _sprite != null and _sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		_sprite.frame_changed.disconnect(_on_sprite_frame_changed)
	_sprite = sprite
	if _sprite != null and is_inside_tree() and not _sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		_sprite.frame_changed.connect(_on_sprite_frame_changed)

func _warn_on_invalid_frames(animation_name: StringName, frame_indices: Array[int], track_name: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if animation_name == StringName():
		return
	if not _sprite.sprite_frames.has_animation(animation_name):
		return
	var total_frames := _sprite.sprite_frames.get_frame_count(animation_name)
	for frame_index in frame_indices:
		if frame_index <= 0:
			continue
		if frame_index > total_frames:
			push_warning("StalkerMotionAudioComponent (%s): указан кадр %d, но всего кадров %d." % [track_name, frame_index, total_frames])

func _on_sprite_frame_changed() -> void:
	if _sprite == null:
		return
	var animation_name: StringName = StringName(_sprite.animation)
	var frame_index := _sprite.frame
	handle_animation_frame(animation_name, frame_index)

func handle_animation_frame(animation_name: StringName, frame_index: int) -> void:
	if _is_matching_frame(animation_name, frame_index, step_animation_name, step_frame_indices):
		_play_track_sound(_step_player, step_sounds, step_volume_db, step_pitch_min, step_pitch_max)
		step_triggered.emit(frame_index, animation_name)
		motion_event_triggered.emit(&"step", frame_index, animation_name)

	if _is_matching_frame(animation_name, frame_index, scrape_animation_name, scrape_frame_indices):
		_play_track_sound(_scrape_player, scrape_sounds, scrape_volume_db, scrape_pitch_min, scrape_pitch_max)
		scrape_triggered.emit(frame_index, animation_name)
		motion_event_triggered.emit(&"scrape", frame_index, animation_name)

func _is_matching_frame(animation_name: StringName, frame_index: int, required_animation: StringName, frame_indices: Array[int]) -> bool:
	if required_animation != StringName() and animation_name != required_animation:
		return false
	return frame_indices.has(frame_index + 1)

func _play_track_sound(
		player: AudioStreamPlayer,
		sounds: Array[AudioStream],
		volume_db: float,
		pitch_min: float,
		pitch_max: float
	) -> void:
	if player == null or sounds.is_empty():
		return
	player.bus = audio_bus
	player.stream = sounds.pick_random()
	player.volume_db = volume_db
	player.pitch_scale = randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
	player.play()
