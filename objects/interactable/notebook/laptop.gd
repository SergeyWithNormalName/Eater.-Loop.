extends InteractiveObject

@export_group("Lab Settings")
## Уникальный ID этой работы (например, lab_1).
@export var quest_id: String = "lab_1"
## Сцена мини-игры (sql_minigame.tscn).
@export var minigame_scene: PackedScene
## Лимит времени на мини-игру.
@export var time_limit: float = 45.0
## Штраф по времени за ошибку.
@export var penalty_time: float = 10.0

@export_group("Legacy Requirements")
## Требовать взаимодействия с холодильником перед запуском.
@export var require_fridge_interaction: bool = false
## Сообщение, если холодильник еще не трогали.
@export var fridge_locked_message: String = ""
## Вручную отключить ноутбук (старые сцены).
@export var is_enabled: bool = true

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

func _ready() -> void:
	super._ready() # Важно для работы базового класса
	
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	_available_light = get_node_or_null(available_light_node) as CanvasItem
	_available_light_secondary = get_node_or_null(available_light_node_secondary) as CanvasItem
	
	_update_visuals()
	
	# Если у нас есть зависимость (Холодильник), подписываемся на её завершение,
	# чтобы включить экран ноутбука, когда холодильник будет открыт.
	if dependency_object:
		if not dependency_object.interaction_finished.is_connected(_on_dependency_finished):
			dependency_object.interaction_finished.connect(_on_dependency_finished)
	
	# Следим за завершением лаб через GameState
	if GameState.has_signal("lab_completed"):
		GameState.lab_completed.connect(func(_id): _update_visuals())
	
	# Старый путь: обновляем визуал после взаимодействия с холодильником
	if require_fridge_interaction and GameState.has_signal("fridge_interacted_changed"):
		GameState.fridge_interacted_changed.connect(func(): _update_visuals())

# --- ВЗАИМОДЕЙСТВИЕ ---
func _on_interact() -> void:
	# Сюда мы попадаем, только если dependency_object (Холодильник) уже выполнен!
	
	if not is_enabled:
		_show_locked_message()
		return

	# Легаси-проверка: нужен холодильник
	if require_fridge_interaction and not GameState.fridge_interacted:
		_show_fridge_locked_message()
		return
	
	# 1. Если работа уже сдана
	if GameState.completed_labs.has(quest_id):
		_handle_completed_interaction()
		return

	# 2. Запускаем мини-игру
	_start_lab_minigame()

func _start_lab_minigame() -> void:
	if minigame_scene == null:
		push_warning("Laptop: Не назначена сцена мини-игры!")
		return
	
	# Создаем игру
	var game = minigame_scene.instantiate()
	_current_minigame = game
	
	# Настраиваем параметры (как в твоем старом коде)
	if "time_limit" in game: game.time_limit = time_limit
	if "penalty_time" in game: game.penalty_time = penalty_time
	if "quest_id" in game: game.quest_id = quest_id
	
	# Добавляем на сцену
	get_tree().root.add_child(game)
	
	# Запускаем через контроллер (для паузы, курсора и таймера)
	if MinigameController:
		MinigameController.start_minigame(game, {
			"pause_game": true,         # Ставим игру на паузу
			"enable_gamepad_cursor": true, # Включаем курсор
			"time_limit": time_limit,   # Передаем лимит времени контроллеру
			"auto_finish_on_timeout": true # Если время выйдет — проигрыш
		})
	
	# Ловим момент закрытия игры
	game.tree_exited.connect(_on_minigame_closed)

func _on_minigame_closed() -> void:
	_current_minigame = null
	_update_visuals()
	
	# Если после игры лаба появилась в списке выполненных — успех
	if GameState.completed_labs.has(quest_id):
		complete_interaction() # Помечаем ноутбук как "пройденный" (для других цепочек)

func _handle_completed_interaction() -> void:
	if show_note_on_completed and completed_note_texture:
		UIMessage.show_note(completed_note_texture)
	else:
		UIMessage.show_text(completed_message)

# --- ВИЗУАЛ ---
func _on_dependency_finished() -> void:
	_update_visuals()

func _update_visuals() -> void:
	# Ноутбук "доступен" (светится), если зависимость выполнена.
	# (Базовый класс сам проверит зависимость при клике, но нам нужно обновить спрайт)
	var is_unlocked = true
	if dependency_object and not dependency_object.is_completed:
		is_unlocked = false
	if require_fridge_interaction and not GameState.fridge_interacted:
		is_unlocked = false
	if not is_enabled:
		is_unlocked = false
	
	if is_unlocked:
		if _sprite and available_sprite: _sprite.texture = available_sprite
		if _available_light: _available_light.visible = true
		if _available_light_secondary: _available_light_secondary.visible = true
	else:
		if _sprite and locked_sprite: _sprite.texture = locked_sprite
		if _available_light: _available_light.visible = false
		if _available_light_secondary: _available_light_secondary.visible = false

func _show_fridge_locked_message() -> void:
	var msg := fridge_locked_message.strip_edges()
	if msg == "":
		_show_locked_message()
		return
	if UIMessage:
		UIMessage.show_text(msg)
	else:
		print(msg)
		
		
