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
## Сообщение, если зависимость не выполнена
@export var locked_message: String = "Сначала нужно сделать что-то другое..."

# --- ВНУТРЕННИЕ ПЕРЕМЕННЫЕ ---
var _interact_area: Area2D = null
var _player_in_range: Node = null
var _prompts_enabled: bool = true
var is_completed: bool = false # <--- ФЛАГ: Выполнен объект или нет

func _ready() -> void:
	input_pickable = false
	_setup_interaction_area()

# --- ЛОГИКА ВЗАИМОДЕЙСТВИЯ ---

# Этот метод вызывает движок при нажатии кнопки (из _unhandled_input)
func request_interact() -> void:
	if not _can_interact():
		return
	
	# 1. ПРОВЕРКА ЗАВИСИМОСТИ (НОВАЯ ЧАСТЬ)
	if dependency_object != null:
		if not dependency_object.is_completed:
			# Если зависимость не выполнена, показываем ошибку и выходим
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
	# Используем твою систему UIMessage
	if UIMessage and UIMessage.has_method("show_message"):
		UIMessage.show_message(locked_message)
	else:
		print("LOCKED: " + locked_message)

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
	if not body.is_in_group("player"):
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
	if _prompts_enabled and auto_prompt:
		_show_prompt()

func _on_player_exited(_player: Node) -> void:
	player_exited.emit(_player)
	_hide_prompt()

func _show_prompt() -> void:
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
	return prompt_text

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
	if not enabled:
		_hide_prompt()
	elif _player_in_range != null:
		_show_prompt()
		
		
