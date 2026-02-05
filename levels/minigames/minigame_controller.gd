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
##    MinigameController.start_minigame(self, MinigameSettings.new())
## 2) Подписаться на сигналы minigame_time_updated / minigame_time_expired.
## 3) По завершению вызвать:
##    MinigameController.finish_minigame(self, success)

signal minigame_started(minigame: Node)
signal minigame_finished(minigame: Node, success: bool)
signal minigame_time_updated(minigame: Node, time_left: float, time_limit: float)
signal minigame_time_expired(minigame: Node)
signal minigame_pause_menu_allowed_changed(allowed: bool)
signal minigame_cancel_allowed_changed(allowed: bool)

@export var default_music_fade_time: float = 0.3
@export var default_cursor_speed: float = 800.0
## Слой для контейнера мини-игр (должен быть ниже меню паузы).
@export var default_minigame_layer: int = 75

const CHASE_MUSIC_PAUSE_FADE_TIME := 0.1

var _active_minigame: Node = null
var _time_limit: float = -1.0
var _time_left: float = 0.0
var _auto_finish_on_timeout: bool = false
var _pause_requested: bool = true
var _pause_prev: bool = false
var _cursor_enabled: bool = true
var _cursor_speed: float = 800.0
var _music_pushed: bool = false
var _music_is_stream: bool = false
var _music_stop_on_finish: bool = false
var _music_fade_time: float = 0.3
var _block_player_movement: bool = true
var _prompts_prev_enabled: bool = true
var _prompts_suspended: bool = false
var _prompts_restore_target: Node = null
var _pause_menu_open: bool = false
var _allow_pause_menu: bool = true
var _allow_cancel_action: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree() and get_tree().has_signal("scene_changed"):
		get_tree().scene_changed.connect(_on_scene_changed)

func _unhandled_input(event: InputEvent) -> void:
	if _active_minigame == null:
		return
	if not _allow_cancel_action:
		return
	if event.is_action_pressed("mg_cancel"):
		_handle_cancel_request()
		get_viewport().set_input_as_handled()

func attach_minigame(minigame: Node, layer_override: int = -1, parent_override: Node = null) -> void:
	if minigame == null:
		return
	if minigame.get_parent() != null:
		if minigame is CanvasLayer:
			var existing_layer := minigame as CanvasLayer
			existing_layer.layer = _resolve_minigame_layer(layer_override)
		return

	var parent := parent_override
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if parent == null:
		return

	var target_layer := _resolve_minigame_layer(layer_override)
	if minigame is CanvasLayer:
		var canvas := minigame as CanvasLayer
		canvas.layer = target_layer
		parent.add_child(canvas)
		return

	var wrapper := CanvasLayer.new()
	wrapper.name = "MinigameLayer"
	wrapper.layer = target_layer
	wrapper.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(wrapper)
	wrapper.add_child(minigame)
	minigame.tree_exited.connect(func():
		if is_instance_valid(wrapper):
			wrapper.queue_free()
	)

func set_pause_menu_open(is_open: bool) -> void:
	_pause_menu_open = is_open

func is_pause_menu_open() -> bool:
	return _pause_menu_open

func get_active_minigame_layer() -> int:
	if _active_minigame == null:
		return default_minigame_layer
	if _active_minigame is CanvasLayer:
		return (_active_minigame as CanvasLayer).layer
	var parent := _active_minigame.get_parent()
	if parent is CanvasLayer:
		return (parent as CanvasLayer).layer
	return default_minigame_layer

func start_minigame(minigame: Node, config: Variant = null) -> void:
	if minigame == null:
		return
	if _active_minigame != null and _active_minigame != minigame:
		finish_minigame(_active_minigame, false)

	_active_minigame = minigame
	var settings := _resolve_settings(config)
	_pause_requested = settings.pause_game
	_cursor_enabled = settings.enable_gamepad_cursor
	_cursor_speed = settings.gamepad_cursor_speed
	_music_fade_time = settings.music_fade_time
	_music_stop_on_finish = settings.stop_music_on_finish
	_auto_finish_on_timeout = settings.auto_finish_on_timeout
	_block_player_movement = settings.block_player_movement
	_allow_pause_menu = settings.allow_pause_menu
	_allow_cancel_action = settings.allow_cancel_action

	_setup_pause()
	_setup_cursor()
	_setup_prompts()
	_setup_timer(settings.time_limit)
	_setup_music(
		settings.music_stream,
		settings.music_volume_db,
		settings.suspend_music
	)
	if MusicManager:
		MusicManager.pause_chase_music(CHASE_MUSIC_PAUSE_FADE_TIME)

	minigame_started.emit(minigame)
	minigame_pause_menu_allowed_changed.emit(_allow_pause_menu)
	minigame_cancel_allowed_changed.emit(_allow_cancel_action)

func finish_minigame(minigame: Node, success: bool = true) -> void:
	if minigame == null:
		return
	if minigame != _active_minigame:
		return
	_active_minigame = null
	_restore_music()
	if MusicManager:
		MusicManager.resume_chase_music(CHASE_MUSIC_PAUSE_FADE_TIME)
	_restore_cursor()
	_restore_pause()
	_schedule_prompt_restore(minigame)
	_clear_timer()
	_block_player_movement = false
	_allow_pause_menu = true
	_allow_cancel_action = false
	minigame_finished.emit(minigame, success)
	minigame_pause_menu_allowed_changed.emit(_allow_pause_menu)
	minigame_cancel_allowed_changed.emit(_allow_cancel_action)

func stop_minigame_music(fade_time: float = -1.0) -> void:
	if MusicManager == null:
		return
	if not _music_pushed:
		return
	if _music_is_stream:
		MusicManager.stop_minigame_music()
		return
	var target_fade := _music_fade_time if fade_time < 0.0 else fade_time
	MusicManager.stop_music(target_fade)

func update_minigame_music(stream: AudioStream, volume_db: float = 999.0, fade_time: float = -1.0) -> void:
	if MusicManager == null:
		return
	if _active_minigame == null:
		return
	var target_fade := _music_fade_time if fade_time < 0.0 else fade_time
	if not _music_pushed:
		_music_pushed = true
		_music_is_stream = true
		MusicManager.start_minigame_music(stream, volume_db)
		return
	var base_volume := MusicManager._resolve_volume(volume_db)
	var mixed_volume := MusicManager._apply_mix(MusicManager.MIX_MINIGAME, base_volume)
	MusicManager.play_music(stream, target_fade, mixed_volume, 0.0, 999.0, MusicManager.SOURCE_MINIGAME)

func get_time_left() -> float:
	return _time_left

func get_time_limit() -> float:
	return _time_limit

func is_active(minigame: Node) -> bool:
	return minigame != null and minigame == _active_minigame

func should_block_player_movement() -> bool:
	return _active_minigame != null and _block_player_movement

func is_pause_menu_allowed() -> bool:
	return _active_minigame == null or _allow_pause_menu

func is_cancel_action_allowed() -> bool:
	return _active_minigame != null and _allow_cancel_action

func _process(delta: float) -> void:
	if _active_minigame != null and not is_instance_valid(_active_minigame):
		_force_clear_active_state()
		return
	if _pause_menu_open:
		return
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
		_music_is_stream = false
		return
	_music_is_stream = stream != null
	if stream == null and not suspend_music:
		return
	_music_pushed = true
	if stream != null:
		MusicManager.start_minigame_music(stream, volume_db)
		return
	MusicManager.push_music(null, _music_fade_time)

func _restore_music() -> void:
	if MusicManager == null:
		return
	if not _music_pushed:
		return
	if _music_is_stream:
		MusicManager.pop_music(0.0)
		_music_pushed = false
		_music_is_stream = false
		return
	if _music_stop_on_finish:
		MusicManager.stop_music(_music_fade_time)
	MusicManager.pop_music(_music_fade_time)
	_music_pushed = false
	_music_is_stream = false

func _resolve_minigame_layer(override_layer: int) -> int:
	return default_minigame_layer if override_layer < 0 else override_layer

func _on_scene_changed(scene: Node = null) -> void:
	_cleanup_orphaned_minigames(scene)

func _cleanup_orphaned_minigames(scene: Node) -> void:
	var current_scene := scene
	if current_scene == null and get_tree():
		current_scene = get_tree().current_scene

	var nodes := get_tree().get_nodes_in_group("minigame_ui")
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if current_scene != null and current_scene.is_ancestor_of(node):
			continue
		if node == _active_minigame:
			finish_minigame(node, false)
		node.queue_free()

	if _active_minigame != null and not is_instance_valid(_active_minigame):
		_force_clear_active_state()

func _force_clear_active_state() -> void:
	if _active_minigame == null:
		return
	_active_minigame = null
	_restore_music()
	_restore_cursor()
	_restore_pause()
	_clear_prompt_restore_target()
	_restore_prompts_if_safe()
	_clear_timer()
	_block_player_movement = false
	_allow_pause_menu = true
	_allow_cancel_action = false

func _handle_cancel_request() -> void:
	if _active_minigame == null:
		return
	if _active_minigame.has_method("on_minigame_cancel"):
		_active_minigame.call("on_minigame_cancel")
		return
	var minigame := _active_minigame
	finish_minigame(minigame, false)
	if minigame != null and is_instance_valid(minigame) and minigame.is_inside_tree():
		minigame.queue_free()

func _resolve_settings(config: Variant) -> MinigameSettings:
	if config is MinigameSettings:
		return config
	var settings := MinigameSettings.new()
	if config is Dictionary:
		if config.has("pause_game"):
			settings.pause_game = bool(config.get("pause_game"))
		if config.has("enable_gamepad_cursor"):
			settings.enable_gamepad_cursor = bool(config.get("enable_gamepad_cursor"))
		if config.has("gamepad_cursor_speed"):
			settings.gamepad_cursor_speed = float(config.get("gamepad_cursor_speed"))
		if config.has("time_limit"):
			settings.time_limit = float(config.get("time_limit"))
		if config.has("music_stream"):
			settings.music_stream = config.get("music_stream")
		if config.has("music_volume_db"):
			settings.music_volume_db = float(config.get("music_volume_db"))
		if config.has("music_fade_time"):
			settings.music_fade_time = float(config.get("music_fade_time"))
		if config.has("suspend_music"):
			settings.suspend_music = bool(config.get("suspend_music"))
		if config.has("auto_finish_on_timeout"):
			settings.auto_finish_on_timeout = bool(config.get("auto_finish_on_timeout"))
		if config.has("stop_music_on_finish"):
			settings.stop_music_on_finish = bool(config.get("stop_music_on_finish"))
		if config.has("block_player_movement"):
			settings.block_player_movement = bool(config.get("block_player_movement"))
		if config.has("allow_pause_menu"):
			settings.allow_pause_menu = bool(config.get("allow_pause_menu"))
		if config.has("allow_cancel_action"):
			settings.allow_cancel_action = bool(config.get("allow_cancel_action"))
	return settings
