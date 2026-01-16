extends Area2D

@export_category("Minigame Settings")
## Уникальный ID этой работы.
@export var quest_id: String = "lab_1" # Уникальный ID этой работы
## Лимит времени на мини-игру.
@export var time_limit: float = 45.0
## Штраф по времени за ошибку.
@export var penalty_time: float = 10.0
## Сцена мини-игры (например, sql_minigame.tscn).
@export var minigame_scene: PackedScene # Сюда перетяни sql_minigame.tscn
## Требовать взаимодействия с холодильником перед запуском.
@export var require_fridge_interaction: bool = false
## Сообщение, если холодильник не посещен.
@export_multiline var fridge_locked_message: String = "Сначала нужно подойти к холодильнику."
## Текстура экрана, когда ноут недоступен.
@export var locked_sprite: Texture2D
## Текстура экрана, когда ноут доступен.
@export var available_sprite: Texture2D
## Узел со спрайтом экрана ноутбука.
@export var sprite_node: NodePath = NodePath("Sprite2D")
## Узел подсветки доступности (основной).
@export var available_light_node: NodePath
## Узел подсветки доступности (дополнительный).
@export var available_light_node_secondary: NodePath
@export_group("Completed Note")
## Показывать записку после выполнения.
@export var show_note_on_completed: bool = false
## Текстура записки после выполнения.
@export var completed_note_texture: Texture2D
## Сообщение, если текстуры записки нет.
@export_multiline var completed_note_empty_message: String = "Тут ничего не написано."

# Флаг, чтобы нельзя было делать лабу дважды
var is_done = false
var _player_inside: bool = false
var _is_interacting: bool = false
var _current_canvas: CanvasLayer = null
var _current_minigame: Node = null
var _sprite: Sprite2D = null
var _available_light: CanvasItem = null
var _available_light_secondary: CanvasItem = null

@onready var interact_area: Area2D = get_node_or_null("InteractArea") as Area2D

func _ready() -> void:
	input_pickable = false
	if interact_area == null:
		interact_area = self
	if interact_area:
		if not interact_area.body_entered.is_connected(_on_body_entered):
			interact_area.body_entered.connect(_on_body_entered)
		if not interact_area.body_exited.is_connected(_on_body_exited):
			interact_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("Laptop: InteractArea не найден.")
	
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	_available_light = get_node_or_null(available_light_node) as CanvasItem
	_available_light_secondary = get_node_or_null(available_light_node_secondary) as CanvasItem
	_update_sprite()
	if GameState.has_signal("lab_completed"):
		GameState.lab_completed.connect(func(_id): _update_sprite())
	if GameState.has_signal("fridge_interacted_changed"):
		GameState.fridge_interacted_changed.connect(func(): _update_sprite())

func _unhandled_input(event: InputEvent) -> void:
	if _is_interacting or not _player_inside:
		return
	
	if event.is_action_pressed("interact"):
		_try_interact()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if InteractionPrompts:
			InteractionPrompts.show_interact(self)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if InteractionPrompts:
			InteractionPrompts.hide_interact(self)

func interact():
	_try_interact()

func _try_interact() -> void:
	if is_done:
		if _show_completed_note_if_enabled():
			return
		UIMessage.show_text("Я уже сдал эту работу...")
		return
	if require_fridge_interaction:
		if not GameState.fridge_interacted:
			UIMessage.show_text(fridge_locked_message)
			return
	if quest_id != "" and GameState.completed_labs.has(quest_id):
		is_done = true
		if _show_completed_note_if_enabled():
			_update_sprite()
			return
		UIMessage.show_text("Я уже сдал эту работу...")
		_update_sprite()
		return
		
	if minigame_scene:
		_is_interacting = true
		_set_prompts_enabled(false)
		var game_instance = minigame_scene.instantiate()
		
		# Передаем параметры в инстанс игры
		game_instance.time_limit = time_limit
		game_instance.penalty_time = penalty_time
		game_instance.quest_id = quest_id
		
		# Добавляем на CanvasLayer (чтобы было поверх всего UI)
		var canvas = CanvasLayer.new()
		canvas.layer = 100
		canvas.add_child(game_instance)
		get_tree().root.add_child(canvas)
		_current_canvas = canvas
		_current_minigame = game_instance
		
		# Подписываемся на завершение (опционально, если нужно визуально выключить ноут)
		game_instance.tree_exited.connect(_on_minigame_closed)

func _on_minigame_closed():
	_is_interacting = false
	_set_prompts_enabled(true)
	# Проверяем через GameState, выполнилась ли работа
	if quest_id in GameState.completed_labs:
		is_done = true
		# Тут можно поменять текстуру экрана ноутбука на "Выключен" или "Рабочий стол"
	_update_sprite()
	
	if _current_canvas != null:
		_current_canvas.queue_free()
		_current_canvas = null
		_current_minigame = null

func _update_sprite() -> void:
	if _sprite == null:
		pass
	if _can_use_now():
		if _sprite and available_sprite:
			_sprite.texture = available_sprite
		if _available_light:
			_available_light.visible = true
		if _available_light_secondary:
			_available_light_secondary.visible = true
	else:
		if _sprite and locked_sprite:
			_sprite.texture = locked_sprite
		if _available_light:
			_available_light.visible = false
		if _available_light_secondary:
			_available_light_secondary.visible = false

func _can_use_now() -> bool:
	if is_done:
		return false
	if quest_id != "" and GameState.completed_labs.has(quest_id):
		return false
	if require_fridge_interaction and not GameState.fridge_interacted:
		return false
	return true

func _show_completed_note_if_enabled() -> bool:
	if not show_note_on_completed:
		return false
	if completed_note_texture:
		UIMessage.show_note(completed_note_texture)
	else:
		UIMessage.show_text(completed_note_empty_message)
	return true

func _set_prompts_enabled(enabled: bool) -> void:
	if InteractionPrompts == null:
		return
	if InteractionPrompts.has_method("set_prompts_enabled"):
		InteractionPrompts.set_prompts_enabled(enabled)
	elif enabled:
		if _player_inside:
			InteractionPrompts.show_interact(self)
	else:
		InteractionPrompts.hide_interact(self)
		
