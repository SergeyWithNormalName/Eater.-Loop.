extends Area2D

@export_category("Minigame Settings")
@export var quest_id: String = "lab_1" # Уникальный ID этой работы
@export var time_limit: float = 45.0
@export var penalty_time: float = 10.0
@export var minigame_scene: PackedScene # Сюда перетяни sql_minigame.tscn

# Флаг, чтобы нельзя было делать лабу дважды
var is_done = false
var _player_inside: bool = false
var _is_interacting: bool = false
var _current_canvas: CanvasLayer = null
var _current_minigame: Node = null

@onready var interact_area: Area2D = get_node_or_null("InteractArea") as Area2D

func _ready() -> void:
	if interact_area:
		if not interact_area.body_entered.is_connected(_on_body_entered):
			interact_area.body_entered.connect(_on_body_entered)
		if not interact_area.body_exited.is_connected(_on_body_exited):
			interact_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("Laptop: InteractArea не найден.")

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
		UIMessage.show_text("Я уже сдал эту работу...")
		return
	if quest_id != "" and GameState.completed_labs.has(quest_id):
		is_done = true
		UIMessage.show_text("Я уже сдал эту работу...")
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
	
	if _current_canvas != null:
		_current_canvas.queue_free()
		_current_canvas = null
		_current_minigame = null
		
