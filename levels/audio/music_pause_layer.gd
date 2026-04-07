extends RefCounted

## MusicPauseLayer — подсистема приоритетной музыки меню паузы.
##
## Владеет собственным `AudioStreamPlayer`, состоянием перехода (idle/opening/
## open/closing) и таймером транзишена. Хост (`MusicManager`) вызывает
## публичные методы из своих оберток и читает `is_active`/`transition_state`
## для `get_music_debug_state()`.

const TRANSITION_IDLE := "idle"
const TRANSITION_OPENING := "opening"
const TRANSITION_OPEN := "open"
const TRANSITION_CLOSING := "closing"

var host: Node
var player: AudioStreamPlayer
var _fade_tween: Tween
var _active: bool = false
var _transition_state: String = TRANSITION_IDLE
var _transition_token: int = 0

func _init(host_node: Node) -> void:
	host = host_node

func setup() -> void:
	if player != null:
		return
	player = AudioStreamPlayer.new()
	host._setup_player(player)
	host.add_child(player)

func reset() -> void:
	stop_immediately()
	_active = false
	_transition_state = TRANSITION_IDLE
	_transition_token = 0

func is_active() -> bool:
	return _active

func get_transition_state() -> String:
	return _transition_state

func start(stream: AudioStream, target_volume: float, fade_out_time: float) -> void:
	_active = true
	_transition_token += 1
	if stream == null:
		stop_immediately()
		_transition_state = TRANSITION_OPEN
		return
	if player == null:
		setup()
	host._ensure_music_loop(stream)
	if player.playing and player.stream == stream:
		_start_or_update(stream, target_volume, 0.0)
		return
	stop_immediately()
	if fade_out_time <= 0.0:
		_start_or_update(stream, target_volume, 0.0)
		return
	_transition_state = TRANSITION_OPENING
	var transition_token := _transition_token
	host.get_tree().create_timer(fade_out_time, true).timeout.connect(func() -> void:
		if transition_token != _transition_token:
			return
		if not _active:
			return
		_start_or_update(stream, target_volume, 0.0)
	, Object.CONNECT_ONE_SHOT)

func stop() -> void:
	_active = false
	_transition_token += 1
	stop_immediately()

func has_player() -> bool:
	return player != null

func is_playing() -> bool:
	return player != null and player.playing

func stop_immediately() -> void:
	_kill_fade_tween()
	if player == null:
		_transition_state = TRANSITION_IDLE
		return
	if player.playing:
		player.stop()
	player.stream_paused = false
	player.volume_db = -80.0
	_transition_state = TRANSITION_IDLE

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

func _start_or_update(stream: AudioStream, target_volume: float, fade_time: float) -> void:
	if player == null:
		return
	_kill_fade_tween()
	var same_stream := player.stream == stream
	player.stream_paused = false
	if not same_stream or not player.playing:
		if player.playing:
			player.stop()
		player.stream = stream
		player.volume_db = -80.0 if fade_time > 0.0 else target_volume
		player.play()
	if fade_time <= 0.0:
		player.volume_db = target_volume
		_transition_state = TRANSITION_OPEN
		return
	_transition_state = TRANSITION_OPENING
	_fade_tween = host.create_tween()
	_fade_tween.tween_property(player, "volume_db", target_volume, fade_time)
	_fade_tween.finished.connect(func() -> void:
		_fade_tween = null
		if _active and player != null and player.playing:
			_transition_state = TRANSITION_OPEN
		else:
			_transition_state = TRANSITION_IDLE
	, Object.CONNECT_ONE_SHOT)

func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null

func _resource_path(resource: Resource) -> String:
	if resource == null:
		return ""
	return String(resource.resource_path)
