extends Area2D

@export_category("Minigame Settings")
@export var quest_id: String = "lab_1" # Уникальный ID этой работы
@export var time_limit: float = 45.0
@export var penalty_time: float = 10.0
@export var minigame_scene: PackedScene # Сюда перетяни sql_minigame.tscn
@export var require_fridge_interaction: bool = false
@export_multiline var fridge_locked_message: String = "Сначала нужно подойти к холодильнику."
@export var locked_sprite: Texture2D
@export var available_sprite: Texture2D
@export var sprite_node: NodePath = NodePath("Sprite2D")
@export var available_light_node: NodePath
@export var available_light_node_secondary: NodePath
@export_group("Completed Note")
@export var show_note_on_completed: bool = false
@export var completed_note_texture: Texture2D
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

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false

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
		
