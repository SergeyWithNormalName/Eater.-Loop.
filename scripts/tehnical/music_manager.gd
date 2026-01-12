extends Node

@export_group("Музыка")
## Длительность плавного перехода по умолчанию.
@export_range(0.0, 10.0, 0.1) var default_fade_time: float = 1.0
## Громкость трека по умолчанию (дБ).
@export_range(-80.0, 6.0, 0.1) var default_volume_db: float = -12.0
## Громкость приглушения (дБ) для временного затухания.
@export_range(-80.0, 0.0, 0.1) var duck_volume_db: float = -80.0
## Шина, в которую уходит музыка.
@export var music_bus: String = "Music"

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer
var _current_stream: AudioStream
var _base_volume_db: float = 0.0
var _is_ducked: bool = false
var _pre_duck_volume_db: float = 0.0
var _fade_tween: Tween
var _stack: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	_setup_player(_player_a)
	_setup_player(_player_b)
	add_child(_player_a)
	add_child(_player_b)
	_active_player = _player_a
	_inactive_player = _player_b

func play_music(stream: AudioStream, fade_time: float = -1.0, volume_db: float = 999.0, start_position: float = 0.0) -> void:
	if stream == null:
		stop_music(fade_time)
		return

	var target_fade := _resolve_fade_time(fade_time)
	var target_volume := _resolve_volume(volume_db)

	if _current_stream == stream and _active_player.playing:
		_base_volume_db = target_volume
		_is_ducked = false
		_pre_duck_volume_db = target_volume
		_fade_volume(_active_player, target_volume, target_fade)
		return

	_current_stream = stream
	_base_volume_db = target_volume
	_is_ducked = false
	_pre_duck_volume_db = target_volume

	_inactive_player.stream = stream
	_inactive_player.volume_db = -80.0
	_inactive_player.play()
	_seek_if_possible(_inactive_player, start_position)

	_crossfade_players(_active_player, _inactive_player, target_volume, target_fade)

func stop_music(fade_time: float = -1.0) -> void:
	if not _active_player.playing:
		return
	_is_ducked = false
	var target_fade := _resolve_fade_time(fade_time)
	_fade_volume(_active_player, -80.0, target_fade, true)

func duck_music(fade_time: float = -1.0, volume_db: float = 999.0) -> void:
	if not _active_player.playing:
		return
	if not _is_ducked:
		_pre_duck_volume_db = _base_volume_db
	_is_ducked = true
	var target_fade := _resolve_fade_time(fade_time)
	var target_volume := _resolve_duck_volume(volume_db)
	_fade_volume(_active_player, target_volume, target_fade)

func restore_music_volume(fade_time: float = -1.0) -> void:
	if not _active_player.playing:
		return
	if not _is_ducked:
		return
	_is_ducked = false
	var target_fade := _resolve_fade_time(fade_time)
	_fade_volume(_active_player, _pre_duck_volume_db, target_fade)

func push_music(stream: AudioStream, fade_time: float = -1.0, volume_db: float = 999.0) -> void:
	var entry := {
		"stream": _current_stream,
		"volume_db": _base_volume_db,
		"position": _get_playback_position(_active_player),
		"was_playing": _active_player.playing
	}
	_stack.append(entry)
	play_music(stream, fade_time, volume_db)

func pop_music(fade_time: float = -1.0) -> void:
	if _stack.is_empty():
		return
	var entry: Dictionary = _stack.pop_back()
	var stream: AudioStream = entry.get("stream", null)
	if stream == null:
		stop_music(fade_time)
		return
	var volume_db: float = entry.get("volume_db", default_volume_db)
	var position: float = entry.get("position", 0.0)
	play_music(stream, fade_time, volume_db, position)

func clear_stack() -> void:
	_stack.clear()

func _setup_player(player: AudioStreamPlayer) -> void:
	player.bus = music_bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = -80.0

func _resolve_fade_time(fade_time: float) -> float:
	return default_fade_time if fade_time < 0.0 else fade_time

func _resolve_volume(volume_db: float) -> float:
	return default_volume_db if volume_db > 500.0 else volume_db

func _resolve_duck_volume(volume_db: float) -> float:
	return duck_volume_db if volume_db > 500.0 else volume_db

func _fade_volume(player: AudioStreamPlayer, target_db: float, duration: float, stop_after: bool = false) -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", target_db, duration)
	if stop_after:
		_fade_tween.tween_callback(player.stop)

func _crossfade_players(from_player: AudioStreamPlayer, to_player: AudioStreamPlayer, target_db: float, duration: float) -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	if from_player.playing:
		_fade_tween.tween_property(from_player, "volume_db", -80.0, duration)
	_fade_tween.tween_property(to_player, "volume_db", target_db, duration)
	_fade_tween.set_parallel(false)
	_fade_tween.finished.connect(func():
		if from_player.playing:
			from_player.stop()
		_swap_active_player(to_player)
	)

func _swap_active_player(new_active: AudioStreamPlayer) -> void:
	_active_player = new_active
	_inactive_player = _player_b if new_active == _player_a else _player_a

func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null

func _seek_if_possible(player: AudioStreamPlayer, position: float) -> void:
	if position <= 0.0:
		return
	if player.stream and player.stream.can_seek:
		player.seek(position)

func _get_playback_position(player: AudioStreamPlayer) -> float:
	if player == null or not player.playing:
		return 0.0
	return player.get_playback_position()
