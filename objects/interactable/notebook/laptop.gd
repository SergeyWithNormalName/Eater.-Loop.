extends InteractiveObject
class_name Laptop

const InteractableAvailabilityVisualScript = preload("res://objects/interactable/shared/interactable_availability_visual.gd")
const LaptopCompletionRewardScript = preload("res://objects/interactable/notebook/laptop_completion_reward.gd")
const UnlockOnDependencyAttemptScript = preload("res://objects/interactable/notebook/unlock_on_dependency_attempt.gd")
const LaptopRewardConfigScript = preload("res://objects/interactable/notebook/laptop_reward_config.gd")

@export_group("Lab Settings")
## Сцена мини-игры (sql_minigame.tscn).
@export var minigame_scene: PackedScene
## Лимит времени на мини-игру.
@export var time_limit: float = 45.0
## Штраф по времени за ошибку.
@export var penalty_time: float = 10.0
## Уникальный ID лабораторной для мульти-режима (пусто = достаточно любой лабораторной текущего цикла).
@export var lab_completion_id: String = ""

@export_group("Lab Audio")
## Музыка, которая будет играть во время лабораторной.
## Если очистить поле, мини-игра использует свой собственный трек.
@export var lab_music_stream: AudioStream = preload("res://music/MusicForLabs.wav")

@export_group("Награда Деньгами")
## Null = обычный ноутбук без денежной награды.
@export var reward_config: Resource
@export_storage var reward_on_work_completion: bool = false
@export_storage var money_system_path: NodePath
@export_storage var reward_money: int = 60
@export_storage var reward_reason: String = "Награда за лабораторную"
@export_storage var reward_once: bool = true

@export_group("Availability")
## Вручную отключить ноутбук.
@export var is_enabled: bool = true:
	set(value):
		_is_enabled = value
		if _is_ready:
			_apply_enabled_state()
	get:
		return _is_enabled
## Разблокировать ноутбук после попытки взаимодействия с зависимым объектом.
@export var unlock_on_dependency_interaction: bool = false

@export_group("Completed Visuals")
## Показывать записку после выполнения вместо повторного запуска?
@export var show_note_on_completed: bool = false
## Текстура записки (результат работы).
@export var completed_note_texture: Texture2D
## Сообщение, если работа сдана, но записки нет.
@export var completed_message: String = "Я уже сдал эту работу. Оценка отличная."

@export_group("Visuals")
## Текстура экрана, когда ноут недоступен (или выключен).
@export var locked_sprite: Texture2D
## Текстура экрана, когда ноут доступен (включен).
@export var available_sprite: Texture2D
## Узел со спрайтом экрана.
@export var sprite_node: NodePath = NodePath("Sprite2D")
## Узлы подсветки (монитор светится).
@export var available_light_node: NodePath
@export var available_light_node_secondary: NodePath

var _sprite: Sprite2D = null
var _available_light: CanvasItem = null
var _available_light_secondary: CanvasItem = null
var _current_minigame: Node = null
var _is_ready: bool = false
var _is_enabled: bool = true
var _availability_visual = InteractableAvailabilityVisualScript.new()
var _completion_reward = LaptopCompletionRewardScript.new()
var _dependency_unlock = UnlockOnDependencyAttemptScript.new()

func _ready() -> void:
	super._ready()
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	_available_light = get_node_or_null(available_light_node) as CanvasItem
	_available_light_secondary = get_node_or_null(available_light_node_secondary) as CanvasItem
	_availability_visual.configure(
		_sprite,
		locked_sprite,
		available_sprite,
		[_available_light, _available_light_secondary]
	)
	_completion_reward.configure(
		_has_reward_config(),
		_get_reward_money_system_path(),
		_get_reward_money(),
		_get_reward_reason(),
		_is_reward_once()
	)
	_dependency_unlock.configure(
		unlock_on_dependency_interaction,
		Callable(self, "_on_dependency_unlock_requested")
	)
	_dependency_unlock.update_dependency(dependency_object)
	_is_ready = true
	_apply_enabled_state()
	if CycleState != null:
		if not CycleState.lab_completed.is_connected(_on_lab_completed):
			CycleState.lab_completed.connect(_on_lab_completed)
		if not CycleState.lab_completed_with_id.is_connected(_on_lab_completed_with_id):
			CycleState.lab_completed_with_id.connect(_on_lab_completed_with_id)
		if not CycleState.cycle_state_reset.is_connected(_update_visuals):
			CycleState.cycle_state_reset.connect(_update_visuals)

func _on_interact() -> void:
	if _is_lab_completed():
		_handle_completed_interaction()
		return
	_start_lab_minigame()

func _start_lab_minigame() -> void:
	if _current_minigame != null:
		return
	if minigame_scene == null:
		push_warning("Laptop: Не назначена сцена мини-игры!")
		return
	var game := minigame_scene.instantiate()
	_current_minigame = game
	if game is Node:
		game.process_mode = Node.PROCESS_MODE_ALWAYS
	if "time_limit" in game:
		game.time_limit = time_limit
	if "penalty_time" in game:
		game.penalty_time = penalty_time
	if "lab_completion_id" in game:
		game.lab_completion_id = lab_completion_id.strip_edges()
	if game is TimedLabMinigameBase:
		if lab_music_stream != null:
			game.lab_music_stream = lab_music_stream
		attach_minigame(game)
		game.call_deferred("setup_lab_music", lab_music_stream)
	else:
		var settings := MinigameSettings.new()
		settings.pause_game = false
		settings.show_mouse_cursor = true
		settings.block_player_movement = true
		settings.time_limit = time_limit
		settings.auto_finish_on_timeout = false
		if lab_music_stream != null:
			settings.music_stream = lab_music_stream
		start_managed_minigame(game, settings)
	game.tree_exited.connect(_on_minigame_closed)

func _on_minigame_closed() -> void:
	_current_minigame = null
	_completion_reward.try_reward(self)
	_update_visuals()
	if _is_lab_completed():
		_handle_completed_interaction()
		complete_interaction()

func _handle_completed_interaction() -> void:
	if show_note_on_completed and completed_note_texture != null:
		UIMessage.show_note(completed_note_texture)
		return
	UIMessage.show_notification(completed_message)

func _on_dependency_finished() -> void:
	super._on_dependency_finished()
	_update_visuals()

func _on_lab_completed() -> void:
	_update_visuals()

func _on_lab_completed_with_id(completed_id: String) -> void:
	var local_id := lab_completion_id.strip_edges()
	if local_id == "":
		return
	if completed_id != local_id:
		return
	_update_visuals()

func _on_dependency_unlock_requested() -> void:
	if not _is_enabled:
		is_enabled = true
	refresh_interaction_state()

func set_dependency_object(new_dependency: InteractiveObject) -> void:
	super.set_dependency_object(new_dependency)
	_dependency_unlock.update_dependency(dependency_object)

func _can_interact() -> bool:
	return _is_enabled

func _show_prompt() -> void:
	if not _is_enabled:
		return
	super._show_prompt()

func _apply_enabled_state() -> void:
	set_interaction_enabled(_is_enabled)
	_update_visuals()

func _is_lab_completed() -> bool:
	if CycleState == null:
		return false
	var local_id := lab_completion_id.strip_edges()
	if local_id != "":
		return bool(CycleState.is_lab_completed(local_id))
	return bool(CycleState.has_completed_any_lab())

func _is_dependency_satisfied() -> bool:
	if _dependency_unlock.is_active():
		return true
	return super._is_dependency_satisfied()

func _is_available_for_player() -> bool:
	if not _is_enabled:
		return false
	if _is_lab_completed():
		return false
	if dependency_object != null and not dependency_object.is_completed and not _dependency_unlock.is_active():
		return false
	return true

func _update_visuals() -> void:
	_availability_visual.apply(_is_available_for_player())

func _on_interaction_state_refreshed() -> void:
	_update_visuals()

func capture_checkpoint_state() -> Dictionary:
	var state := super.capture_checkpoint_state()
	state["is_enabled"] = _is_enabled
	state.merge(_dependency_unlock.capture_state(), true)
	state.merge(_completion_reward.capture_state(), true)
	return state

func apply_checkpoint_state(state: Dictionary) -> void:
	super.apply_checkpoint_state(state)
	_is_enabled = bool(state.get("is_enabled", _is_enabled))
	_dependency_unlock.apply_state(state)
	_completion_reward.apply_state(state)
	_apply_enabled_state()

func _has_reward_config() -> bool:
	if reward_config != null:
		return reward_config.enabled
	return reward_on_work_completion

func _get_reward_money_system_path() -> NodePath:
	if reward_config != null:
		return reward_config.money_system_path
	return money_system_path

func _get_reward_money() -> int:
	if reward_config != null:
		return reward_config.reward_money
	return reward_money

func _get_reward_reason() -> String:
	if reward_config != null:
		return reward_config.reward_reason
	return reward_reason

func _is_reward_once() -> bool:
	if reward_config != null:
		return reward_config.reward_once
	return reward_once
