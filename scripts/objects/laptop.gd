extends Sprite2D

@export_category("Minigame Settings")
@export var quest_id: String = "lab_1" # Уникальный ID этой работы
@export var time_limit: float = 45.0
@export var penalty_time: float = 10.0
@export var minigame_scene: PackedScene # Сюда перетяни sql_minigame.tscn

# Флаг, чтобы нельзя было делать лабу дважды
var is_done = false

func interact():
	if is_done:
		UIMessage.show_message("Я уже сдал эту работу...")
		return
		
	if minigame_scene:
		var game_instance = minigame_scene.instantiate()
		
		# Передаем параметры в инстанс игры
		game_instance.time_limit = time_limit
		game_instance.penalty_time = penalty_time
		game_instance.quest_id = quest_id
		
		# Добавляем на CanvasLayer (чтобы было поверх всего UI)
		var canvas = CanvasLayer.new()
		canvas.add_child(game_instance)
		get_tree().root.add_child(canvas)
		
		# Подписываемся на завершение (опционально, если нужно визуально выключить ноут)
		game_instance.tree_exited.connect(_on_minigame_closed)

func _on_minigame_closed():
	# Проверяем через GameState, выполнилась ли работа
	if quest_id in GameState.completed_labs:
		is_done = true
		# Тут можно поменять текстуру экрана ноутбука на "Выключен" или "Рабочий стол"
		
