extends Area2D
class_name InteractiveObject

# --- СИГНАЛЫ ---
signal player_entered(player: Node)
signal player_exited(player: Node)
signal interaction_requested(player: Node)
signal interaction_finished # <--- НОВЫЙ СИГНАЛ: для цепочек событий

# --- НАСТРОЙКИ ВЗАИМОДЕЙСТВИЯ (СТАРЫЕ) ---
@export_group("Interaction")
## Узел Area2D для зоны взаимодействия (пусто — использовать сам объект).
@export var interact_area_node: NodePath = NodePath("")
## Текст подсказки взаимодействия.
@export var prompt_text: String = ""
## Показывать подсказку автоматически при входе в зону.
@export var auto_prompt: bool = true
## Обрабатывать ввод автоматически.
@export var handle_input: bool = true

@export_group("Prompt Indicator")
## Смещение спрайта подсказки относительно центра объекта.
@export var prompt_offset: Vector2 = Vector2.ZERO

# --- НОВЫЕ НАСТРОЙКИ (ЗАВИСИМОСТИ) ---
@export_group("Dependency System")
## Если true, объект помечается выполненным после первого использования
@export var one_shot: bool = false
## Объект, который должен быть выполнен перед использованием этого
@export var dependency_object: InteractiveObject 
## Сообщение при блокировке (если показывать вручную)
@export var locked_message: String = "Сначала нужно сделать что-то другое..."

# --- ВНУТРЕННИЕ ПЕРЕМЕННЫЕ ---
var _interact_area: Area2D = null
var _player_in_range: Node = null
var _prompts_enabled: bool = true
var is_completed: bool = false # <--- ФЛАГ: Выполнен объект или нет
var _feedback_audio_player: AudioStreamPlayer2D = null

func _ready() -> void:
	if not is_in_group(GroupNames.CHECKPOINT_STATEFUL):
		add_to_group(GroupNames.CHECKPOINT_STATEFUL)
	input_pickable = false
	_setup_feedback_audio()
	_setup_interaction_area()
	set_dependency_object(dependency_object)

func capture_checkpoint_state() -> Dictionary:
	return {
		"is_completed": is_completed,
		"handle_input": handle_input,
		"auto_prompt": auto_prompt,
		"prompts_enabled": _prompts_enabled,
	}

func apply_checkpoint_state(state: Dictionary) -> void:
	is_completed = bool(state.get("is_completed", is_completed))
	handle_input = bool(state.get("handle_input", handle_input))
	auto_prompt = bool(state.get("auto_prompt", auto_prompt))
	_prompts_enabled = bool(state.get("prompts_enabled", _prompts_enabled))
	refresh_interaction_state()

# --- ЛОГИКА ВЗАИМОДЕЙСТВИЯ ---

# Этот метод вызывает движок при нажатии кнопки (из _unhandled_input)
func request_interact() -> void:
	if not _can_interact():
		return
	if not _is_dependency_satisfied():
		_show_locked_message()
		return

	# 2. ЕСЛИ ВСЁ ОК — ЗАПУСКАЕМ ДЕЙСТВИЕ
	interaction_requested.emit(_player_in_range)
	_on_interact()
	
	# 3. ЕСЛИ ОБЪЕКТ ОДНОРАЗОВЫЙ
	if one_shot:
		complete_interaction()

# Вызывай это в дочерних скриптах, когда действие успешно завершено
func complete_interaction() -> void:
	is_completed = true
	interaction_finished.emit()

# Переопределяй этот метод в наследниках (Frizzer, Generator, Laptop)
func _on_interact() -> void:
	pass

# Показ сообщения о блокировке
func _show_locked_message() -> void:
	var localized_message := tr(locked_message)
	if UIMessage:
		UIMessage.show_notification(localized_message)
	else:
		print("LOCKED: " + localized_message)

# --- ИНФРАСТРУКТУРА (ОСТАВЛЯЕМ БЕЗ ИЗМЕНЕНИЙ) ---

func _setup_interaction_area() -> void:
	_interact_area = get_node_or_null(interact_area_node) as Area2D
	if _interact_area == null:
		_interact_area = self
	if _interact_area:
		if not _interact_area.body_entered.is_connected(_on_interact_area_body_entered):
			_interact_area.body_entered.connect(_on_interact_area_body_entered)
		if not _interact_area.body_exited.is_connected(_on_interact_area_body_exited):
			_interact_area.body_exited.connect(_on_interact_area_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not handle_input:
		return
	if _player_in_range == null:
		return
	if event.is_action_pressed(_get_interact_action()):
		request_interact()

func _can_interact() -> bool:
	return true

func _get_interact_action() -> String:
	return "interact"

func _on_interact_area_body_entered(body: Node) -> void:
	if not body.is_in_group(GroupNames.PLAYER):
		return
	_player_in_range = body
	_on_player_entered(body)

func _on_interact_area_body_exited(body: Node) -> void:
	if body != _player_in_range:
		return
	_player_in_range = null
	_on_player_exited(body)

func _on_player_entered(_player: Node) -> void:
	player_entered.emit(_player)
	_refresh_prompt_state()

func _on_player_exited(_player: Node) -> void:
	player_exited.emit(_player)
	_hide_prompt()

func _show_prompt() -> void:
	if not _allow_prompt_display():
		_hide_prompt()
		return
	if UIMessage:
		UIMessage.show_interact_prompt(self, _get_prompt_text())
	elif InteractionPrompts:
		InteractionPrompts.show_interact(self, _get_prompt_text())

func _hide_prompt() -> void:
	if UIMessage:
		UIMessage.hide_interact_prompt(self)
	elif InteractionPrompts:
		InteractionPrompts.hide_interact(self)

func _get_prompt_text() -> String:
	return tr(prompt_text)

func get_prompt_world_position() -> Vector2:
	var anchor := _interact_area
	if anchor == null:
		return to_global(prompt_offset)
	return anchor.to_global(prompt_offset)

func get_interacting_player() -> Node:
	return _player_in_range

func is_player_in_range() -> bool:
	return _player_in_range != null

func set_prompts_enabled(enabled: bool) -> void:
	_prompts_enabled = enabled
	_refresh_prompt_state()

func set_interaction_enabled(enabled: bool) -> void:
	handle_input = enabled
	set_prompts_enabled(enabled)

func refresh_interaction_state() -> void:
	_refresh_prompt_state()
	_on_interaction_state_refreshed()

func set_dependency_object(new_dependency: InteractiveObject) -> void:
	if dependency_object == new_dependency:
		refresh_interaction_state()
		return
	_disconnect_dependency_listener()
	dependency_object = new_dependency
	_setup_dependency_listener()
	refresh_interaction_state()

func attach_minigame(minigame: Node, layer_override: int = -1, parent_override: Node = null) -> Node:
	if minigame == null:
		return null
	if MinigameController:
		MinigameController.attach_minigame(minigame, layer_override, parent_override)
		return minigame
	var parent := parent_override
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if parent != null:
		parent.add_child(minigame)
	return minigame

func start_managed_minigame(minigame: Node, settings: Variant = null, layer_override: int = -1, parent_override: Node = null) -> Node:
	if minigame == null:
		return null
	attach_minigame(minigame, layer_override, parent_override)
	if settings != null and MinigameController and not MinigameController.is_active(minigame):
		MinigameController.start_minigame(minigame, settings)
	return minigame

func _setup_dependency_listener() -> void:
	if dependency_object == null:
		return
	if not is_instance_valid(dependency_object):
		return
	if not dependency_object.interaction_finished.is_connected(_on_dependency_finished):
		dependency_object.interaction_finished.connect(_on_dependency_finished)

func _disconnect_dependency_listener() -> void:
	if dependency_object == null:
		return
	if not is_instance_valid(dependency_object):
		return
	if dependency_object.interaction_finished.is_connected(_on_dependency_finished):
		dependency_object.interaction_finished.disconnect(_on_dependency_finished)

func _on_dependency_finished() -> void:
	refresh_interaction_state()

func _is_dependency_satisfied() -> bool:
	if dependency_object == null:
		return true
	return dependency_object.is_completed

func _is_interaction_available() -> bool:
	if not _can_interact():
		return false
	if not _is_dependency_satisfied():
		return false
	return true

func _allow_prompt_display() -> bool:
	if not _prompts_enabled:
		return false
	return _is_interaction_available()

func _refresh_prompt_state() -> void:
	if _player_in_range == null:
		_hide_prompt()
		return
	if auto_prompt and _allow_prompt_display():
		_show_prompt()
	else:
		_hide_prompt()

func play_feedback_sfx(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_min: float = 1.0,
	pitch_max: float = 1.0
) -> void:
	if stream == null:
		return
	if _feedback_audio_player == null:
		_setup_feedback_audio()
	if _feedback_audio_player == null:
		return
	_feedback_audio_player.stream = stream
	_feedback_audio_player.volume_db = volume_db
	_feedback_audio_player.pitch_scale = randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
	_feedback_audio_player.play()

func _on_interaction_state_refreshed() -> void:
	pass

func _setup_feedback_audio() -> void:
	if _feedback_audio_player != null:
		return
	_feedback_audio_player = AudioStreamPlayer2D.new()
	_feedback_audio_player.bus = "Sounds"
	_feedback_audio_player.max_distance = 2000.0
	add_child(_feedback_audio_player)
