extends Node

## MusicManager — единый слой управления музыкой.
##
## Основные режимы:
## - play_music(stream, fade, volume): базовое воспроизведение трека с кроссфейдом.
## - push_music(stream, fade, volume): временно заменить музыку (мини-игры, события).
## - pop_music(fade): вернуть предыдущий трек из стека.
## - duck_music / restore_music_volume: временно приглушить основной трек.
## - play_ambient_music / start_event_music / start_distortion_music / start_minigame_music:
##   обертки с миксом по типам.
## - start_pause_menu_music / stop_pause_menu_music: приоритетное меню-пауза с паузой базы.
##
## Музыка погони:
## - set_chase_music_source(source, active, stream, volume_db, fade_out_time)
##   Музыка погони играет от первого активного источника, пока он не пропадет.

@export_group("Музыка")
## Длительность плавного перехода по умолчанию.
@export_range(0.0, 10.0, 0.1) var default_fade_time: float = 1.0
## Громкость трека по умолчанию (дБ).
@export_range(-80.0, 6.0, 0.1) var default_volume_db: float = -12.0
## Громкость приглушения (дБ) для временного затухания.
@export_range(-80.0, 0.0, 0.1) var duck_volume_db: float = -80.0
## Шина, в которую уходит музыка.
@export var music_bus: String = "Music"

@export_group("Mix Settings")
## Ресурс настроек микса по типам музыки.
@export var mix_settings: Resource

@export_group("Музыка погони")
## Музыка погони за игроком.
@export var runner_music_stream: AudioStream = preload("res://music/RunnerHARDMUSIC.wav")
## Громкость музыки погони (дБ).
@export_range(-80.0, 6.0, 0.1) var runner_music_volume_db: float = -8.0
## Длительность плавного перехода музыки погони.
@export_range(0.0, 10.0, 0.1) var runner_music_fade_time: float = 1.0
## Длительность быстрого глушения основной музыки при погоне.
@export_range(0.0, 10.0, 0.1) var chase_base_duck_time: float = 0.2

const RUNNER_MUSIC_PATH := "res://music/RunnerHARDMUSIC.wav"
const MIX_AMBIENT := "ambient"
const MIX_DISTORTION := "distortion"
const MIX_EVENT := "event"
const MIX_CHASE := "chase"
const MIX_MINIGAME := "minigame"
const MIX_PAUSE := "pause"
const MIX_MENU := "menu"
const PAUSE_REASON_MENU := "pause_menu"
const PAUSE_REASON_GLOBAL := "global"
const SOURCE_MINIGAME := -10

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer
var _current_stream: AudioStream
var _current_source_id: int = 0
var _base_volume_db: float = 0.0
var _is_ducked: bool = false
var _pre_duck_volume_db: float = 0.0
var _last_duck_volume_db: float = 999.0
var _fade_tween: Tween
var _is_crossfading: bool = false
var _crossfade_from: AudioStreamPlayer
var _crossfade_to: AudioStreamPlayer
var _crossfade_target_db: float = 0.0
var _stack: Array[Dictionary] = []
var _runner_player: AudioStreamPlayer
var _runner_fade_tween: Tween
var _runner_sources: Dictionary = {}
var _runner_source_order: Array[int] = []
var _runner_active_source_id: int = 0
var _runner_active: bool = false
var _runner_suppressed: Dictionary = {}
var _runner_active_fade_out_time: float = -1.0
var _runner_pause_position: float = 0.0
var _runner_paused: bool = false
var _runner_global_paused: bool = false
var _chase_base_muted: bool = false
var _event_sources: Dictionary = {}
var _distortion_sources: Dictionary = {}
var _pause_player: AudioStreamPlayer
var _pause_menu_active: bool = false
var _base_pause_reasons: Dictionary = {}
var _base_pause_active: bool = false
var _base_pause_player: AudioStreamPlayer
var _base_pause_restore_db: float = 0.0
var _base_pause_stream: AudioStream
var _base_pause_position: float = 0.0

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
	_pause_player = AudioStreamPlayer.new()
	_setup_player(_pause_player)
	add_child(_pause_player)
	if not _runner_player.finished.is_connected(_on_runner_music_finished):
		_runner_player.finished.connect(_on_runner_music_finished)
	if mix_settings == null:
		var loaded := load("res://music/music_mix_settings.tres")
		if loaded != null:
			mix_settings = loaded
	set_process(true)

func play_music(stream: AudioStream, fade_time: float = -1.0, volume_db: float = 999.0, start_position: float = 0.0, output_volume_db: float = 999.0, source_id: int = 0) -> void:
	if stream == null:
		_current_source_id = 0
		stop_music(fade_time)
		return

	var target_fade := _resolve_fade_time(fade_time)
	var target_volume := _resolve_volume(volume_db)
	var output_volume := target_volume
	if output_volume_db <= 500.0:
		output_volume = output_volume_db
	if _chase_base_muted or _should_mute_base_for_chase():
		output_volume = -80.0

	_current_source_id = source_id

	if _current_stream == stream and _active_player.playing:
		_base_volume_db = target_volume
		_is_ducked = false
		_pre_duck_volume_db = target_volume
		_fade_volume(_active_player, output_volume, target_fade)
		return

	_current_stream = stream
	_base_volume_db = target_volume
	_is_ducked = false
	_pre_duck_volume_db = target_volume

	_inactive_player.stream = stream
	_inactive_player.volume_db = -80.0
	_inactive_player.play()
	_seek_if_possible(_inactive_player, start_position)

	_crossfade_players(_active_player, _inactive_player, output_volume, target_fade)

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
	_last_duck_volume_db = target_volume
	if _chase_base_muted:
		return
	_fade_volume(player, target_volume, target_fade)

func restore_music_volume(fade_time: float = -1.0) -> void:
	_kill_fade_tween()
	var player := _resolve_playing_player()
	if player == null or not player.playing:
		return
	if not _is_ducked:
		return
	_is_ducked = false
	if _chase_base_muted:
		return
	var target_fade := _resolve_fade_time(fade_time)
	_fade_volume(player, _pre_duck_volume_db, target_fade)

func push_music(stream: AudioStream, fade_time: float = -1.0, volume_db: float = 999.0, source_id: int = 0) -> void:
	var player := _resolve_playing_player()
	var was_playing := player != null and player.playing
	var duck_volume := _last_duck_volume_db
	if duck_volume > 500.0:
		duck_volume = _resolve_duck_volume(999.0)
	var entry := {
		"stream": _current_stream if was_playing else null,
		"volume_db": _base_volume_db,
		"source_id": _current_source_id if was_playing else 0,
		"position": _get_playback_position(player),
		"was_playing": was_playing,
		"was_ducked": _is_ducked,
		"duck_volume_db": duck_volume
	}
	_stack.append(entry)
	play_music(stream, fade_time, volume_db, 0.0, 999.0, source_id)

func pop_music(fade_time: float = -1.0) -> void:
	if _stack.is_empty():
		return
	var entry: Dictionary = _stack.pop_back()
	var stream: AudioStream = entry.get("stream", null)
	var was_playing: bool = bool(entry.get("was_playing", true))
	var was_ducked: bool = bool(entry.get("was_ducked", false))
	var source_id: int = int(entry.get("source_id", 0))
	if stream == null or not was_playing:
		stop_music(fade_time)
		return
	var volume_db: float = entry.get("volume_db", default_volume_db)
	var position: float = entry.get("position", 0.0)
	if was_ducked:
		var entry_duck_volume_db: float = entry.get("duck_volume_db", _resolve_duck_volume(999.0))
		play_music(stream, fade_time, volume_db, position, entry_duck_volume_db, source_id)
		_is_ducked = true
		_pre_duck_volume_db = _base_volume_db
		_last_duck_volume_db = entry_duck_volume_db
		return
	play_music(stream, fade_time, volume_db, position, 999.0, source_id)

func clear_stack() -> void:
	_stack.clear()

func get_current_stream() -> AudioStream:
	return _current_stream

func remove_music_from_stack(stream: AudioStream) -> void:
	if stream == null:
		return
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i].get("stream", null) == stream:
			_stack.remove_at(i)

func remove_music_from_stack_by_source_id(source_id: int) -> void:
	if source_id == 0:
		return
	for i in range(_stack.size() - 1, -1, -1):
		if int(_stack[i].get("source_id", 0)) == source_id:
			_stack.remove_at(i)

func play_ambient_music(stream: AudioStream, fade_time: float = -1.0, volume_db: float = 999.0) -> void:
	if stream == null:
		stop_music(fade_time)
		return
	var target_volume := _apply_mix(MIX_AMBIENT, _resolve_volume(volume_db))
	play_music(stream, fade_time, target_volume, 0.0, 999.0, 0)

func play_menu_music(stream: AudioStream, fade_time: float = -1.0, volume_db: float = 999.0) -> void:
	if stream == null:
		stop_music(fade_time)
		return
	var target_volume := _apply_mix(MIX_MENU, _resolve_volume(volume_db))
	play_music(stream, fade_time, target_volume, 0.0, 999.0, 0)

func stop_ambient_music(stream: AudioStream, fade_time: float = -1.0) -> void:
	if stream == null:
		return
	if _current_stream == stream:
		stop_music(fade_time)
	remove_music_from_stack(stream)

func start_distortion_music(source: Object, stream: AudioStream, fade_time: float = -1.0, volume_db: float = 999.0) -> void:
	if source == null or stream == null:
		return
	var source_id := source.get_instance_id()
	_distortion_sources[source_id] = true
	var target_volume := _apply_mix(MIX_DISTORTION, _resolve_volume(volume_db))
	push_music(stream, fade_time, target_volume, source_id)

func stop_distortion_music(source: Object, fade_time: float = -1.0) -> void:
	if source == null:
		return
	var source_id := source.get_instance_id()
	_distortion_sources.erase(source_id)
	if _current_source_id == source_id:
		pop_music(fade_time)
	else:
		remove_music_from_stack_by_source_id(source_id)

func start_event_music(source: Object, stream: AudioStream, fade_in_time: float = -1.0, volume_db: float = 999.0, fade_out_time: float = 1.0) -> void:
	if source == null or stream == null:
		return
	var source_id := source.get_instance_id()
	_event_sources[source_id] = {"fade_out_time": fade_out_time}
	var target_volume := _apply_mix(MIX_EVENT, _resolve_volume(volume_db))
	push_music(stream, fade_in_time, target_volume, source_id)

func stop_event_music(source: Object, fade_out_time: float = -1.0) -> void:
	if source == null:
		return
	var source_id := source.get_instance_id()
	var target_fade := fade_out_time
	if target_fade < 0.0:
		var entry: Dictionary = _event_sources.get(source_id, {})
		if entry.has("fade_out_time"):
			target_fade = float(entry.get("fade_out_time"))
	if target_fade < 0.0:
		target_fade = default_fade_time
	if _current_source_id == source_id:
		pop_music(target_fade)
	else:
		remove_music_from_stack_by_source_id(source_id)
	_event_sources.erase(source_id)

func start_minigame_music(stream: AudioStream, volume_db: float = 999.0) -> void:
	if stream == null:
		return
	var target_volume := _apply_mix(MIX_MINIGAME, _resolve_volume(volume_db))
	push_music(stream, 0.0, target_volume, SOURCE_MINIGAME)

func stop_minigame_music() -> void:
	if _current_source_id != SOURCE_MINIGAME:
		return
	var player := _resolve_playing_player()
	if player == null:
		return
	player.stop()

func start_pause_menu_music(stream: AudioStream, fade_out_time: float = -1.0, volume_db: float = 999.0) -> void:
	_pause_menu_active = true
	var target_fade := _resolve_fade_time(fade_out_time)
	_request_base_pause(PAUSE_REASON_MENU, target_fade)
	pause_chase_music(target_fade)
	if stream == null:
		return
	if _pause_player == null:
		_pause_player = AudioStreamPlayer.new()
		_setup_player(_pause_player)
		add_child(_pause_player)
	var target_volume := _apply_mix(MIX_PAUSE, _resolve_volume(volume_db))
	_pause_player.stream = stream
	_pause_player.volume_db = target_volume
	if _pause_player.playing:
		_pause_player.stop()
	_pause_player.play()

func stop_pause_menu_music(resume_fade_time: float = -1.0) -> void:
	if not _pause_menu_active:
		return
	_pause_menu_active = false
	if _pause_player != null and _pause_player.playing:
		_pause_player.stop()
	var target_fade := _resolve_fade_time(resume_fade_time)
	_request_base_resume(PAUSE_REASON_MENU, target_fade)
	resume_chase_music(target_fade)

func pause_all_music(fade_time: float = -1.0) -> void:
	var target_fade := _resolve_fade_time(fade_time)
	_request_base_pause(PAUSE_REASON_GLOBAL, target_fade)
	pause_chase_music(target_fade)

func resume_all_music(fade_time: float = -1.0) -> void:
	var target_fade := _resolve_fade_time(fade_time)
	_request_base_resume(PAUSE_REASON_GLOBAL, target_fade)
	resume_chase_music(target_fade)

func set_chase_music_source(source: Object, active: bool, stream: AudioStream = null, volume_db: float = 999.0, fade_out_time: float = -1.0) -> void:
	if source == null:
		return
	var id := source.get_instance_id()
	if active:
		_runner_sources[id] = {
			"stream": stream,
			"volume_db": volume_db,
			"fade_out_time": fade_out_time
		}
		if not _runner_source_order.has(id):
			_runner_source_order.append(id)
		if _runner_active_source_id == 0:
			_set_active_runner_source(id)
	else:
		_runner_sources.erase(id)
		_runner_suppressed.erase(id)
		_runner_source_order.erase(id)
		if _runner_active_source_id == id:
			_runner_active_source_id = 0
			_set_next_runner_source()
	_update_runner_music_state()

func set_chase_music_suppressed(source: Object, suppressed: bool) -> void:
	if source == null:
		return
	var id := source.get_instance_id()
	if suppressed:
		_runner_suppressed[id] = true
	else:
		_runner_suppressed.erase(id)
	_update_runner_music_state()

func is_chase_active() -> bool:
	return _runner_active and not _runner_global_paused and not _runner_paused

func pause_chase_music(fade_time: float = -1.0) -> void:
	if _runner_global_paused:
		return
	_runner_global_paused = true
	var target_fade := _resolve_fade_time(fade_time)
	_pause_runner_music(target_fade, true)
	_sync_chase_base_mute()

func resume_chase_music(fade_time: float = -1.0) -> void:
	if not _runner_global_paused:
		return
	_runner_global_paused = false
	if not _runner_active:
		return
	var target_fade := _resolve_fade_time(fade_time)
	if _runner_paused:
		_resume_runner_music(target_fade, true)
	elif _runner_player == null or not _runner_player.playing:
		_start_runner_music()
	_sync_chase_base_mute()

func clear_chase_music_sources(fade_time: float = -1.0) -> void:
	_runner_sources.clear()
	_runner_source_order.clear()
	_runner_suppressed.clear()
	_runner_active_source_id = 0
	_runner_active = false
	_runner_paused = false
	_runner_pause_position = 0.0
	_runner_global_paused = false
	_runner_active_fade_out_time = -1.0
	var target_fade := _resolve_fade_time(fade_time)
	if _runner_player != null and _runner_player.playing:
		_fade_runner_volume(-80.0, target_fade, true)

func _process(_delta: float) -> void:
	_sync_chase_base_mute()
	if not _runner_active or _runner_global_paused or _runner_paused:
		return
	if _runner_player == null:
		_start_runner_music()
		return
	if not _runner_player.playing:
		_start_runner_music()

func _update_runner_music_state() -> void:
	var next_id := _get_next_runner_source_id()
	var should_play := next_id != 0
	if next_id != _runner_active_source_id:
		if next_id == 0:
			_runner_active_source_id = 0
		else:
			_set_active_runner_source(next_id)
	_runner_active = should_play
	if _runner_global_paused:
		if _runner_player != null and _runner_player.playing:
			_pause_runner_music(runner_music_fade_time, true)
		return
	if should_play:
		if _runner_paused:
			_resume_runner_music(runner_music_fade_time)
		elif _runner_player == null or not _runner_player.playing:
			_start_runner_music()
	else:
		if _runner_player != null and _runner_player.playing:
			_pause_runner_music(_get_runner_fade_out_time(), false)
		if _runner_sources.is_empty():
			_runner_pause_position = 0.0
			_runner_paused = false
	_sync_chase_base_mute()

func _set_active_runner_source(source_id: int) -> void:
	if source_id == 0:
		return
	var data: Dictionary = _runner_sources.get(source_id, {})
	var stream: AudioStream = data.get("stream", null)
	if stream != null:
		var prev_stream := runner_music_stream
		runner_music_stream = stream
		if prev_stream != stream:
			_runner_pause_position = 0.0
	var volume_db: float = data.get("volume_db", 999.0)
	if volume_db <= 500.0:
		runner_music_volume_db = volume_db
	var fade_out_time: float = data.get("fade_out_time", -1.0)
	_runner_active_fade_out_time = fade_out_time if fade_out_time >= 0.0 else -1.0
	_runner_active_source_id = source_id

func _set_next_runner_source() -> void:
	var next_id := _get_next_runner_source_id()
	if next_id != 0:
		_set_active_runner_source(next_id)

func _get_next_runner_source_id() -> int:
	for source_id in _runner_source_order:
		if _runner_sources.has(source_id) and not _is_runner_source_suppressed(source_id):
			return source_id
	return 0

func _is_runner_source_suppressed(source_id: int) -> bool:
	return bool(_runner_suppressed.get(source_id, false))

func _get_runner_fade_out_time() -> float:
	if _runner_active_fade_out_time >= 0.0:
		return _runner_active_fade_out_time
	return runner_music_fade_time

func _start_runner_music(start_position: float = 0.0, fade_in_time: float = -1.0) -> void:
	var stream := _resolve_runner_stream()
	if stream == null or _runner_player == null:
		return
	_ensure_runner_loop(stream)
	_runner_player.stream = stream
	if _runner_fade_tween and _runner_fade_tween.is_running():
		_runner_fade_tween.kill()
	var target_volume := _apply_mix(MIX_CHASE, runner_music_volume_db)
	if fade_in_time >= 0.0:
		_runner_player.volume_db = -80.0
	else:
		_runner_player.volume_db = target_volume
	if _runner_player.playing:
		_runner_player.stop()
	_runner_player.play()
	_seek_if_possible(_runner_player, start_position)
	if fade_in_time >= 0.0:
		_fade_runner_volume(target_volume, fade_in_time, false)

func _stop_runner_music() -> void:
	if _runner_player == null:
		return
	if not _runner_player.playing:
		return
	_fade_runner_volume(-80.0, runner_music_fade_time, true)

func _pause_runner_music(fade_time: float, pause_stream_only: bool = false) -> void:
	if _runner_player == null:
		_runner_paused = true
		return
	if _runner_player.playing:
		_runner_pause_position = _runner_player.get_playback_position()
		_runner_paused = true
		if pause_stream_only:
			if _runner_fade_tween and _runner_fade_tween.is_running():
				_runner_fade_tween.kill()
			if fade_time <= 0.0:
				_runner_player.volume_db = -80.0
				_runner_player.stream_paused = true
				return
			_runner_fade_tween = create_tween()
			_runner_fade_tween.tween_property(_runner_player, "volume_db", -80.0, fade_time)
			_runner_fade_tween.tween_callback(func():
				if is_instance_valid(_runner_player):
					_runner_player.stream_paused = true
			)
			return
		_fade_runner_volume(-80.0, fade_time, true)
	else:
		_runner_paused = true

func _resume_runner_music(fade_time: float, resume_stream_only: bool = false) -> void:
	if _runner_player == null:
		return
	if resume_stream_only:
		if _runner_fade_tween and _runner_fade_tween.is_running():
			_runner_fade_tween.kill()
		_runner_paused = false
		_runner_player.stream_paused = false
		var target_volume := _apply_mix(MIX_CHASE, runner_music_volume_db)
		if _runner_player.playing:
			if fade_time <= 0.0:
				_runner_player.volume_db = target_volume
				return
			_fade_runner_volume(target_volume, fade_time, false)
			return
		if _runner_pause_position <= 0.0:
			_start_runner_music()
			return
		_start_runner_music(_runner_pause_position)
		return
	var start_pos := _runner_pause_position
	_runner_paused = false
	_start_runner_music(start_pos)

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

func _apply_mix(category: String, volume_db: float) -> float:
	var offset := 0.0
	if mix_settings != null:
		match category:
			MIX_AMBIENT:
				offset = mix_settings.ambient_db_offset
			MIX_DISTORTION:
				offset = mix_settings.distortion_db_offset
			MIX_EVENT:
				offset = mix_settings.event_db_offset
			MIX_CHASE:
				offset = mix_settings.chase_db_offset
			MIX_MINIGAME:
				offset = mix_settings.minigame_db_offset
			MIX_PAUSE:
				offset = mix_settings.pause_db_offset
			MIX_MENU:
				offset = mix_settings.menu_db_offset
	var mixed := volume_db + offset
	return clamp(mixed, -80.0, 6.0)

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

func _request_base_pause(reason: String, fade_time: float) -> void:
	_base_pause_reasons[reason] = true
	if _base_pause_active:
		return
	var player := _resolve_playing_player()
	if player == null:
		_base_pause_active = true
		_base_pause_player = player
		return
	_kill_fade_tween()
	_base_pause_player = player
	_base_pause_stream = player.stream
	_base_pause_position = _get_playback_position(player)
	_base_pause_restore_db = player.volume_db
	_base_pause_active = true
	if not player.playing:
		return
	if fade_time <= 0.0:
		player.volume_db = -80.0
		player.stream_paused = true
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", -80.0, fade_time)
	_fade_tween.tween_callback(func():
		if is_instance_valid(player):
			_base_pause_position = _get_playback_position(player)
			player.stream_paused = true
	)

func _request_base_resume(reason: String, fade_time: float) -> void:
	if not _base_pause_reasons.has(reason):
		return
	_base_pause_reasons[reason] = false
	for key in _base_pause_reasons.keys():
		if bool(_base_pause_reasons.get(key, false)):
			return
	if not _base_pause_active:
		return
	_base_pause_active = false
	var player := _base_pause_player
	var resume_stream := _base_pause_stream
	var resume_position := _base_pause_position
	_base_pause_player = null
	_base_pause_stream = null
	_base_pause_position = 0.0
	if player == null:
		return
	if resume_stream != null and player.stream != resume_stream:
		player.stream = resume_stream
	if player.playing:
		player.stream_paused = false
	else:
		if player.stream == null:
			return
		player.volume_db = -80.0 if fade_time > 0.0 else _base_pause_restore_db
		player.play()
		_seek_if_possible(player, resume_position)
	if fade_time <= 0.0:
		player.volume_db = _base_pause_restore_db
		return
	_fade_volume(player, _base_pause_restore_db, fade_time)

func _should_mute_base_for_chase() -> bool:
	if not _runner_active or _runner_global_paused or _runner_paused:
		return false
	return true

func _get_base_target_volume_db() -> float:
	return _last_duck_volume_db if _is_ducked else _base_volume_db

func _sync_chase_base_mute() -> void:
	var should_mute := _should_mute_base_for_chase()
	if should_mute == _chase_base_muted:
		return
	_chase_base_muted = should_mute
	if _pause_menu_active or _base_pause_active:
		return
	var player := _resolve_playing_player()
	if player == null or not player.playing:
		return
	var target_fade := chase_base_duck_time
	var target_volume := -80.0 if should_mute else _get_base_target_volume_db()
	_fade_volume(player, target_volume, target_fade)
