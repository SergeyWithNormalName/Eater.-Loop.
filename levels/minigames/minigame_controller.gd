extends Node

## Центральный контроллер мини-игр.
##
## Назначение:
## - единая логика паузы и курсора
## - управление фоновой музыкой мини-игры через MusicManager
## - обработка геймпадного курсора
## - общий таймер мини-игры
##
## Использование:
## 1) В мини-игре вызвать:
##    MinigameController.start_minigame(self, {
##      "pause_game": true,
##      "enable_gamepad_cursor": true,
##      "time_limit": 60.0,
##      "music_stream": some_stream,
##      "music_volume_db": -12.0,
##      "music_fade_time": 0.3,
##      "auto_finish_on_timeout": false
##    })
## 2) Подписаться на сигналы minigame_time_updated / minigame_time_expired.
## 3) По завершению вызвать:
##    MinigameController.finish_minigame(self, success)

signal minigame_started(minigame: Node)
signal minigame_finished(minigame: Node, success: bool)
signal minigame_time_updated(minigame: Node, time_left: float, time_limit: float)
signal minigame_time_expired(minigame: Node)

@export var default_music_fade_time: float = 0.3
@export var default_cursor_speed: float = 800.0

var _active_minigame: Node = null
var _time_limit: float = -1.0
var _time_left: float = 0.0
var _auto_finish_on_timeout: bool = false
var _pause_requested: bool = true
var _pause_prev: bool = false
var _cursor_enabled: bool = true
var _cursor_speed: float = 800.0
var _music_pushed: bool = false
var _music_stop_on_finish: bool = false
var _music_fade_time: float = 0.3
var _block_player_movement: bool = true
var _prompts_prev_enabled: bool = true
var _prompts_suspended: bool = false
var _prompts_restore_target: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_minigame(minigame: Node, config: Dictionary = {}) -> void:
	if minigame == null:
		return
	if _active_minigame != null and _active_minigame != minigame:
		finish_minigame(_active_minigame, false)

	_active_minigame = minigame
	_pause_requested = bool(config.get("pause_game", true))
	_cursor_enabled = bool(config.get("enable_gamepad_cursor", true))
	_cursor_speed = float(config.get("gamepad_cursor_speed", default_cursor_speed))
	_music_fade_time = float(config.get("music_fade_time", default_music_fade_time))
	_music_stop_on_finish = bool(config.get("stop_music_on_finish", false))
	_auto_finish_on_timeout = bool(config.get("auto_finish_on_timeout", false))
	_block_player_movement = bool(config.get("block_player_movement", true))

	_setup_pause()
	_setup_cursor()
	_setup_prompts()
	_setup_timer(config.get("time_limit", -1.0))
	_setup_music(
		config.get("music_stream", null),
		float(config.get("music_volume_db", 999.0)),
		bool(config.get("suspend_music", false))
	)

	minigame_started.emit(minigame)

func finish_minigame(minigame: Node, success: bool = true) -> void:
	if minigame == null:
		return
	if minigame != _active_minigame:
		return
	_active_minigame = null
	_restore_music()
	_restore_cursor()
	_restore_pause()
	_schedule_prompt_restore(minigame)
	_clear_timer()
	_block_player_movement = false
	minigame_finished.emit(minigame, success)

func stop_minigame_music(fade_time: float = -1.0) -> void:
	if MusicManager == null:
		return
	if not _music_pushed:
		return
	var target_fade := _music_fade_time if fade_time < 0.0 else fade_time
	MusicManager.stop_music(target_fade)

func update_minigame_music(stream: AudioStream, volume_db: float = 999.0, fade_time: float = -1.0) -> void:
	if MusicManager == null:
		return
	if _active_minigame == null:
		return
	var target_fade := _music_fade_time if fade_time < 0.0 else fade_time
	var target_volume := volume_db
	if not _music_pushed:
		_music_pushed = true
		MusicManager.push_music(stream, target_fade, target_volume)
		return
	MusicManager.play_music(stream, target_fade, target_volume)

func get_time_left() -> float:
	return _time_left

func get_time_limit() -> float:
	return _time_limit

func is_active(minigame: Node) -> bool:
	return minigame != null and minigame == _active_minigame

func should_block_player_movement() -> bool:
	return _active_minigame != null and _block_player_movement

func _process(delta: float) -> void:
	_update_timer(delta)
	_update_gamepad_cursor(delta)

func _update_timer(delta: float) -> void:
	if _active_minigame == null:
		return
	if _time_limit <= 0.0:
		return
	_time_left = max(0.0, _time_left - delta)
	minigame_time_updated.emit(_active_minigame, _time_left, _time_limit)
	if _time_left <= 0.0:
		minigame_time_expired.emit(_active_minigame)
		if _auto_finish_on_timeout:
			finish_minigame(_active_minigame, false)

func _update_gamepad_cursor(delta: float) -> void:
	if _active_minigame == null:
		return
	if not _cursor_enabled:
		return
	var joy_vector = Input.get_vector("mg_cursor_left", "mg_cursor_right", "mg_cursor_up", "mg_cursor_down")
	if joy_vector.length() <= 0.1:
		return
	var current_mouse = get_viewport().get_mouse_position()
	var new_pos = current_mouse + joy_vector * _cursor_speed * delta
	var screen_rect = get_viewport().get_visible_rect().size
	new_pos.x = clamp(new_pos.x, 0, screen_rect.x)
	new_pos.y = clamp(new_pos.y, 0, screen_rect.y)
	get_viewport().warp_mouse(new_pos)

func _setup_pause() -> void:
	if not _pause_requested:
		return
	_pause_prev = get_tree().paused
	get_tree().paused = true

func _restore_pause() -> void:
	if not _pause_requested:
		return
	get_tree().paused = _pause_prev

func _setup_cursor() -> void:
	if not _cursor_enabled:
		return
	if CursorManager:
		CursorManager.request_visible(self)

func _restore_cursor() -> void:
	if not _cursor_enabled:
		return
	if CursorManager:
		CursorManager.release_visible(self)

func _setup_prompts() -> void:
	if InteractionPrompts == null:
		return
	if _prompts_suspended:
		return
	if InteractionPrompts.has_method("are_prompts_enabled"):
		_prompts_prev_enabled = InteractionPrompts.are_prompts_enabled()
	else:
		_prompts_prev_enabled = true
	InteractionPrompts.set_prompts_enabled(false)
	_prompts_suspended = true

func _restore_prompts() -> void:
	if not _prompts_suspended:
		return
	if InteractionPrompts:
		InteractionPrompts.set_prompts_enabled(_prompts_prev_enabled)
	_prompts_suspended = false

func _schedule_prompt_restore(minigame: Node) -> void:
	if not _prompts_suspended:
		return
	_clear_prompt_restore_target()
	if minigame != null and minigame.is_inside_tree():
		_prompts_restore_target = minigame
		if not minigame.tree_exited.is_connected(_on_prompt_restore_target_exited):
			minigame.tree_exited.connect(_on_prompt_restore_target_exited)
		return
	_restore_prompts_if_safe()

func _restore_prompts_if_safe() -> void:
	if _active_minigame != null:
		return
	_restore_prompts()

func _clear_prompt_restore_target() -> void:
	if _prompts_restore_target == null:
		return
	if is_instance_valid(_prompts_restore_target):
		if _prompts_restore_target.tree_exited.is_connected(_on_prompt_restore_target_exited):
			_prompts_restore_target.tree_exited.disconnect(_on_prompt_restore_target_exited)
	_prompts_restore_target = null

func _on_prompt_restore_target_exited() -> void:
	_prompts_restore_target = null
	_restore_prompts_if_safe()

func _setup_timer(limit: float) -> void:
	_time_limit = float(limit)
	if _time_limit > 0.0:
		_time_left = _time_limit
	else:
		_time_left = 0.0

func _clear_timer() -> void:
	_time_limit = -1.0
	_time_left = 0.0

func _setup_music(stream: AudioStream, volume_db: float, suspend_music: bool) -> void:
	if MusicManager == null:
		return
	if stream == null and not suspend_music:
		return
	var target_fade := _music_fade_time
	var target_volume := volume_db
	_music_pushed = true
	MusicManager.push_music(stream, target_fade, target_volume)

func _restore_music() -> void:
	if MusicManager == null:
		return
	if not _music_pushed:
		return
	if _music_stop_on_finish:
		MusicManager.stop_music(_music_fade_time)
	MusicManager.pop_music(_music_fade_time)
	_music_pushed = false
