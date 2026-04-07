extends RefCounted

## MusicChaseSystem — подсистема музыки погони.
##
## Владеет собственным `AudioStreamPlayer`, списком источников (runner) и
## состоянием pause/resume. Ничего не знает про базовые плееры музыки, кроме
## того, что может запросить у хоста актуальную громкость микса и сообщить
## хосту "нужно ли глушить базу" (`should_mute_base()`).
##
## Хост (`MusicManager`) вызывает публичные методы из своих публичных оберток
## (`set_chase_music_source`, `pause_chase_music`, ...) и дергает `process_tick`
## и `sync_base_mute` из `_process`.

const RUNNER_MUSIC_PATH := "res://music/RunnerHARDMUSIC.wav"
const MIX_CHASE := "chase"

var host: Node
var player: AudioStreamPlayer
var _fade_tween: Tween
var _sources: Dictionary = {}
var _source_order: Array[int] = []
var _active_source_id: int = 0
var _active: bool = false
var _suppressed: Dictionary = {}
var _active_fade_out_time: float = -1.0
var _pause_position: float = 0.0
var _paused: bool = false
var _global_paused: bool = false

func _init(host_node: Node) -> void:
	host = host_node

func setup() -> void:
	if player != null:
		return
	player = AudioStreamPlayer.new()
	host._setup_player(player)
	host.add_child(player)
	if not player.finished.is_connected(_on_finished):
		player.finished.connect(_on_finished)

func reset() -> void:
	_sources.clear()
	_source_order.clear()
	_suppressed.clear()
	_active_source_id = 0
	_active_fade_out_time = -1.0
	_pause_position = 0.0
	_paused = false
	_global_paused = false
	_active = false
	_kill_fade_tween()
	if player != null:
		player.stop()
		player.stream_paused = false
		player.stream = null
		player.volume_db = -80.0

func set_source(source: Object, stream: AudioStream, volume_db: float, fade_out_time: float) -> void:
	if source == null:
		return
	var id := source.get_instance_id()
	_sources[id] = {
		"stream": stream,
		"volume_db": volume_db,
		"fade_out_time": fade_out_time
	}
	if not _source_order.has(id):
		_source_order.append(id)
	if _active_source_id == 0:
		_set_active_source(id)
	update_state()

func remove_source(source: Object) -> void:
	if source == null:
		return
	var id := source.get_instance_id()
	_sources.erase(id)
	_suppressed.erase(id)
	_source_order.erase(id)
	if _active_source_id == id:
		_active_source_id = 0
		var next_id := _get_next_source_id()
		if next_id != 0:
			_set_active_source(next_id)
	update_state()

func set_suppressed(source: Object, suppressed: bool) -> void:
	if source == null:
		return
	var id := source.get_instance_id()
	if suppressed:
		_suppressed[id] = true
	else:
		_suppressed.erase(id)
	update_state()

func pause(fade_time: float) -> void:
	if _global_paused:
		return
	_global_paused = true
	_pause_music(fade_time, true)

func resume(fade_time: float) -> void:
	if not _global_paused:
		return
	_global_paused = false
	if not _active:
		return
	if _paused:
		_resume_music(fade_time, true)
	elif player == null or not player.playing:
		_start_music()

func clear_all(fade_time: float) -> void:
	_sources.clear()
	_source_order.clear()
	_suppressed.clear()
	_active_source_id = 0
	_active = false
	_paused = false
	_pause_position = 0.0
	_global_paused = false
	_active_fade_out_time = -1.0
	_kill_fade_tween()
	if player != null and player.playing:
		_fade_volume(-80.0, fade_time, true)

func is_active() -> bool:
	return _active and not _global_paused and not _paused

func should_mute_base() -> bool:
	if not _active or _global_paused or _paused:
		return false
	return true

func has_sources() -> bool:
	return not _sources.is_empty()

func process_tick() -> void:
	if not _active or _global_paused or _paused:
		return
	if player == null:
		_start_music()
		return
	if not player.playing:
		_start_music()

func describe_player() -> Dictionary:
	if player == null:
		return {
			"exists": false,
			"playing": false,
			"stream_path": "",
			"volume_db": -80.0,
			"stream_paused": false
		}
	return {
		"exists": true,
		"playing": player.playing,
		"stream_path": _resource_path(player.stream),
		"volume_db": player.volume_db,
		"stream_paused": player.stream_paused
	}

func update_state() -> void:
	var next_id := _get_next_source_id()
	var should_play := next_id != 0
	if next_id != _active_source_id:
		if next_id == 0:
			_active_source_id = 0
		else:
			_set_active_source(next_id)
	_active = should_play
	var fade_time: float = host.runner_music_fade_time
	if _global_paused:
		if player != null and player.playing:
			_pause_music(fade_time, true)
		return
	if should_play:
		if _paused:
			_resume_music(fade_time, false)
		elif player == null or not player.playing:
			_start_music()
	else:
		if player != null and player.playing:
			_pause_music(_get_fade_out_time(), false)
		if _sources.is_empty():
			_pause_position = 0.0
			_paused = false

func _set_active_source(source_id: int) -> void:
	if source_id == 0:
		return
	var data: Dictionary = _sources.get(source_id, {})
	var stream: AudioStream = data.get("stream", null)
	if stream != null:
		var prev_stream: AudioStream = host.runner_music_stream
		host.runner_music_stream = stream
		if prev_stream != stream:
			_pause_position = 0.0
	var volume_db: float = data.get("volume_db", 999.0)
	if volume_db <= 500.0:
		host.runner_music_volume_db = volume_db
	var fade_out_time: float = data.get("fade_out_time", -1.0)
	_active_fade_out_time = fade_out_time if fade_out_time >= 0.0 else -1.0
	_active_source_id = source_id

func _get_next_source_id() -> int:
	for source_id in _source_order:
		if _sources.has(source_id) and not _is_source_suppressed(source_id):
			return source_id
	return 0

func _is_source_suppressed(source_id: int) -> bool:
	return bool(_suppressed.get(source_id, false))

func _get_fade_out_time() -> float:
	if _active_fade_out_time >= 0.0:
		return _active_fade_out_time
	return host.runner_music_fade_time

func _start_music(start_position: float = 0.0, fade_in_time: float = -1.0) -> void:
	var stream := _resolve_stream()
	if stream == null or player == null:
		return
	host._ensure_music_loop(stream)
	player.stream = stream
	_kill_fade_tween()
	var target_volume: float = host._apply_mix(MIX_CHASE, host.runner_music_volume_db)
	if fade_in_time >= 0.0:
		player.volume_db = -80.0
	else:
		player.volume_db = target_volume
	if player.playing:
		player.stop()
	player.play()
	host._seek_if_possible(player, start_position)
	if fade_in_time >= 0.0:
		_fade_volume(target_volume, fade_in_time, false)

func _pause_music(fade_time: float, pause_stream_only: bool = false) -> void:
	if player == null:
		_paused = true
		return
	if player.playing:
		_pause_position = player.get_playback_position()
		_paused = true
		if pause_stream_only:
			_kill_fade_tween()
			if fade_time <= 0.0:
				player.volume_db = -80.0
				player.stream_paused = true
				return
			_fade_tween = host.create_tween()
			_fade_tween.tween_property(player, "volume_db", -80.0, fade_time)
			_fade_tween.tween_callback(func():
				if is_instance_valid(player):
					player.stream_paused = true
			)
			return
		_fade_volume(-80.0, fade_time, true)
	else:
		_paused = true

func _resume_music(fade_time: float, resume_stream_only: bool = false) -> void:
	if player == null:
		return
	if resume_stream_only:
		_kill_fade_tween()
		_paused = false
		player.stream_paused = false
		var target_volume: float = host._apply_mix(MIX_CHASE, host.runner_music_volume_db)
		if player.playing:
			if fade_time <= 0.0:
				player.volume_db = target_volume
				return
			_fade_volume(target_volume, fade_time, false)
			return
		if _pause_position <= 0.0:
			_start_music()
			return
		_start_music(_pause_position)
		return
	var start_pos := _pause_position
	_paused = false
	_start_music(start_pos)

func _fade_volume(target_db: float, duration: float, stop_after: bool = false) -> void:
	_kill_fade_tween()
	_fade_tween = host.create_tween()
	_fade_tween.tween_property(player, "volume_db", target_db, duration)
	if stop_after:
		_fade_tween.tween_callback(player.stop)

func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null

func _resolve_stream() -> AudioStream:
	if host.runner_music_stream != null:
		return host.runner_music_stream
	var loaded: Resource = load(RUNNER_MUSIC_PATH)
	return loaded as AudioStream

func _on_finished() -> void:
	if _active:
		_start_music()

func _resource_path(resource: Resource) -> String:
	if resource == null:
		return ""
	return String(resource.resource_path)
