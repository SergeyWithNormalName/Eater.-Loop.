extends Area2D

## Базовый класс для интерактивных объектов.
##
## Реализует:
## - обработку зоны взаимодействия
## - отображение подсказки
## - базовую обработку ввода
##
## Переопределите:
## - _on_interact() для действия
## - _get_interact_action() для другой кнопки
## - _show_prompt() / _hide_prompt() для кастомных подсказок

@export_group("Interaction")
## Узел Area2D для зоны взаимодействия (пусто — использовать сам объект).
@export var interact_area_node: NodePath = NodePath("")
## Текст подсказки взаимодействия (если пусто — дефолтный текст).
@export var prompt_text: String = ""
## Показывать подсказку автоматически при входе в зону.
@export var auto_prompt: bool = true
## Обрабатывать ввод автоматически.
@export var handle_input: bool = true

signal player_entered(player: Node)
signal player_exited(player: Node)
signal interaction_requested(player: Node)

var _interact_area: Area2D = null
var _player_in_range: Node = null
var _prompts_enabled: bool = true

func _ready() -> void:
	input_pickable = false
	_setup_interaction_area()

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

func request_interact() -> void:
	if not _can_interact():
		return
	interaction_requested.emit(_player_in_range)
	_on_interact()

func _can_interact() -> bool:
	return true

func _on_interact() -> void:
	pass

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
