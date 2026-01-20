extends Node

## MusicManager — единый слой управления музыкой.
##
## Основные режимы:
## - play_music(stream, fade, volume): базовое воспроизведение трека с кроссфейдом.
## - push_music(stream, fade, volume): временно заменить музыку (мини-игры, меню).
## - pop_music(fade): вернуть предыдущий трек из стека.
## - duck_music / restore_music_volume: временно приглушить основной трек.
##
## Музыка погони:
## - configure_runner_music(stream, volume_db, fade_time)
## - set_runner_music_active(source, true/false)
##   Музыка погони играет, пока есть хотя бы один активный источник.

@export_group("Музыка")
## Длительность плавного перехода по умолчанию.
@export_range(0.0, 10.0, 0.1) var default_fade_time: float = 1.0
## Громкость трека по умолчанию (дБ).
@export_range(-80.0, 6.0, 0.1) var default_volume_db: float = -12.0
## Громкость приглушения (дБ) для временного затухания.
@export_range(-80.0, 0.0, 0.1) var duck_volume_db: float = -80.0
## Шина, в которую уходит музыка.
@export var music_bus: String = "Music"

@export_group("Музыка погони")
## Музыка погони за игроком.
@export var runner_music_stream: AudioStream = preload("res://audio/MusicEtc/RunnerHARDMUSIC.wav")
## Громкость музыки погони (дБ).
@export_range(-80.0, 6.0, 0.1) var runner_music_volume_db: float = -8.0
## Длительность плавного перехода музыки погони.
@export_range(0.0, 10.0, 0.1) var runner_music_fade_time: float = 1.0

const RUNNER_MUSIC_PATH := "res://audio/MusicEtc/RunnerHARDMUSIC.wav"

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer
var _current_stream: AudioStream
var _base_volume_db: float = 0.0
var _is_ducked: bool = false
var _pre_duck_volume_db: float = 0.0
var _fade_tween: Tween
var _is_crossfading: bool = false
var _crossfade_from: AudioStreamPlayer
var _crossfade_to: AudioStreamPlayer
var _crossfade_target_db: float = 0.0
var _stack: Array[Dictionary] = []
var _runner_player: AudioStreamPlayer
var _runner_fade_tween: Tween
var _runner_sources: Dictionary = {}
var _runner_active: bool = false

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
	_runner_player = AudioStreamPlayer.new()
	_setup_player(_runner_player)
	add_child(_runner_player)
	if not _runner_player.finished.is_connected(_on_runner_music_finished):
		_runner_player.finished.connect(_on_runner_music_finished)
	set_process(true)

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
	_kill_fade_tween()
	var player := _resolve_playing_player()
	if player == null or not player.playing:
		return
	_is_ducked = false
	var target_fade := _resolve_fade_time(fade_time)
	_fade_volume(player, -80.0, target_fade, true)

func duck_music(fade_time: float = -1.0, volume_db: float = 999.0) -> void:
	_kill_fade_tween()
	var player := _resolve_playing_player()
	if player == null or not player.playing:
		return
	if not _is_ducked:
		_pre_duck_volume_db = _base_volume_db
	_is_ducked = true
	var target_fade := _resolve_fade_time(fade_time)
	var target_volume := _resolve_duck_volume(volume_db)
	_fade_volume(player, target_volume, target_fade)

func restore_music_volume(fade_time: float = -1.0) -> void:
	_kill_fade_tween()
	var player := _resolve_playing_player()
	if player == null or not player.playing:
		return
	if not _is_ducked:
		return
	_is_ducked = false
	var target_fade := _resolve_fade_time(fade_time)
	_fade_volume(player, _pre_duck_volume_db, target_fade)

func push_music(stream: AudioStream, fade_time: float = -1.0, volume_db: float = 999.0) -> void:
	var player := _resolve_playing_player()
	var was_playing := player != null and player.playing
	var entry := {
		"stream": _current_stream if was_playing else null,
		"volume_db": _base_volume_db,
		"position": _get_playback_position(player),
		"was_playing": was_playing
	}
	_stack.append(entry)
	play_music(stream, fade_time, volume_db)

func pop_music(fade_time: float = -1.0) -> void:
	if _stack.is_empty():
		return
	var entry: Dictionary = _stack.pop_back()
	var stream: AudioStream = entry.get("stream", null)
	var was_playing: bool = bool(entry.get("was_playing", true))
	if stream == null or not was_playing:
		stop_music(fade_time)
		return
	var volume_db: float = entry.get("volume_db", default_volume_db)
	var position: float = entry.get("position", 0.0)
	play_music(stream, fade_time, volume_db, position)

func clear_stack() -> void:
	_stack.clear()

func set_runner_music_active(source: Object, active: bool) -> void:
	if source == null:
		return
	var id := source.get_instance_id()
	if active:
		_runner_sources[id] = true
	else:
		_runner_sources.erase(id)
	_update_runner_music_state()

func configure_runner_music(stream: AudioStream, volume_db: float = 999.0, fade_time: float = -1.0) -> void:
	if stream != null:
		runner_music_stream = stream
	if volume_db <= 500.0:
		runner_music_volume_db = volume_db
	if fade_time >= 0.0:
		runner_music_fade_time = fade_time

func _process(_delta: float) -> void:
	if not _runner_active:
		return
	if _runner_player == null:
		_start_runner_music()
		return
	if not _runner_player.playing:
		_start_runner_music()

func _update_runner_music_state() -> void:
	var should_play := not _runner_sources.is_empty()
	_runner_active = should_play
	if should_play:
		if _runner_player == null or not _runner_player.playing:
			_start_runner_music()
	else:
		_stop_runner_music()

func _start_runner_music() -> void:
	var stream := _resolve_runner_stream()
	if stream == null or _runner_player == null:
		return
	_ensure_runner_loop(stream)
	_runner_player.stream = stream
	if _runner_fade_tween and _runner_fade_tween.is_running():
		_runner_fade_tween.kill()
	_runner_player.volume_db = runner_music_volume_db
	if _runner_player.playing:
		_runner_player.stop()
	_runner_player.play()

func _stop_runner_music() -> void:
	if _runner_player == null:
		return
	if not _runner_player.playing:
		return
	_fade_runner_volume(-80.0, runner_music_fade_time, true)

func _fade_runner_volume(target_db: float, duration: float, stop_after: bool = false) -> void:
	if _runner_fade_tween and _runner_fade_tween.is_running():
		_runner_fade_tween.kill()
	_runner_fade_tween = create_tween()
	_runner_fade_tween.tween_property(_runner_player, "volume_db", target_db, duration)
	if stop_after:
		_runner_fade_tween.tween_callback(_runner_player.stop)

func _ensure_runner_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return
	if stream is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = stream
		ogg.loop = true
		return
	if stream is AudioStreamMP3:
		var mp3: AudioStreamMP3 = stream
		mp3.loop = true

func _resolve_runner_stream() -> AudioStream:
	if runner_music_stream != null:
		return runner_music_stream
	var loaded: Resource = load(RUNNER_MUSIC_PATH)
	return loaded as AudioStream

func _on_runner_music_finished() -> void:
	if _runner_active:
		_start_runner_music()

func _setup_player(player: AudioStreamPlayer) -> void:
	var bus_name := music_bus
	if AudioServer.get_bus_index(bus_name) == -1:
		bus_name = "Master"
	player.bus = bus_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = -80.0

func _resolve_fade_time(fade_time: float) -> float:
	return default_fade_time if fade_time < 0.0 else fade_time

func _resolve_volume(volume_db: float) -> float:
	return default_volume_db if volume_db > 500.0 else volume_db

func _resolve_duck_volume(volume_db: float) -> float:
	return duck_volume_db if volume_db > 500.0 else volume_db

func _resolve_playing_player() -> AudioStreamPlayer:
	if _active_player and _active_player.playing:
		return _active_player
	if _inactive_player and _inactive_player.playing:
		return _inactive_player
	return _active_player

func _fade_volume(player: AudioStreamPlayer, target_db: float, duration: float, stop_after: bool = false) -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", target_db, duration)
	if stop_after:
		_fade_tween.tween_callback(player.stop)

func _crossfade_players(from_player: AudioStreamPlayer, to_player: AudioStreamPlayer, target_db: float, duration: float) -> void:
	_kill_fade_tween()
	_is_crossfading = true
	_crossfade_from = from_player
	_crossfade_to = to_player
	_crossfade_target_db = target_db
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
		_clear_crossfade_state()
	)

func _swap_active_player(new_active: AudioStreamPlayer) -> void:
	_active_player = new_active
	_inactive_player = _player_b if new_active == _player_a else _player_a

func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null
	if _is_crossfading:
		_finalize_crossfade()

func _finalize_crossfade() -> void:
	if not _is_crossfading:
		return
	var to_player := _crossfade_to
	var from_player := _crossfade_from
	if to_player:
		to_player.volume_db = _crossfade_target_db
	if from_player and from_player != to_player and from_player.playing:
		from_player.stop()
	if to_player and to_player.playing:
		_swap_active_player(to_player)
	elif from_player:
		_swap_active_player(from_player)
	_clear_crossfade_state()

func _clear_crossfade_state() -> void:
	_is_crossfading = false
	_crossfade_from = null
	_crossfade_to = null
	_crossfade_target_db = 0.0

func _seek_if_possible(player: AudioStreamPlayer, position: float) -> void:
	if position <= 0.0:
		return
	var stream := player.stream
	if stream == null:
		return
	if stream.has_method("can_seek") and stream.can_seek():
		player.seek(position)

func _get_playback_position(player: AudioStreamPlayer) -> float:
	if player == null or not player.playing:
		return 0.0
	return player.get_playback_position()
