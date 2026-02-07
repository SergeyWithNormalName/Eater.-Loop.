extends InteractiveObject


@export_group("Lab Settings")
## Сцена мини-игры (sql_minigame.tscn).
@export var minigame_scene: PackedScene
## Лимит времени на мини-игру.
@export var time_limit: float = 45.0
## Штраф по времени за ошибку.
@export var penalty_time: float = 10.0

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
var _dependency_override: bool = false

func _ready() -> void:
	super._ready() # Важно для работы базового класса
	
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	_available_light = get_node_or_null(available_light_node) as CanvasItem
	_available_light_secondary = get_node_or_null(available_light_node_secondary) as CanvasItem
	
	_is_ready = true
	_apply_enabled_state()
	
	# Если у нас есть зависимость (Холодильник), подписываемся на её завершение,
	# чтобы включить экран ноутбука, когда холодильник будет открыт.
	if dependency_object:
		if not dependency_object.interaction_finished.is_connected(_on_dependency_finished):
			dependency_object.interaction_finished.connect(_on_dependency_finished)
		if unlock_on_dependency_interaction:
			if not dependency_object.interaction_requested.is_connected(_on_dependency_interaction_requested):
				dependency_object.interaction_requested.connect(_on_dependency_interaction_requested)
	
	# Следим за завершением лаб через GameState
	if GameState.has_signal("lab_completed"):
		GameState.lab_completed.connect(_update_visuals)

# --- ВЗАИМОДЕЙСТВИЕ ---
func _on_interact() -> void:
	# Сюда мы попадаем, только если dependency_object (Холодильник) уже выполнен!
	
	# 1. Если работа уже сдана
	if _is_lab_completed():
		_handle_completed_interaction()
		return

	# 2. Запускаем мини-игру
	_start_lab_minigame()

func _start_lab_minigame() -> void:
	if _current_minigame != null:
		return
	if minigame_scene == null:
		push_warning("Laptop: Не назначена сцена мини-игры!")
		return
	
	# Создаем игру
	var game = minigame_scene.instantiate()
	_current_minigame = game
	if game is Node:
		game.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Настраиваем параметры (как в твоем старом коде)
	if "time_limit" in game: game.time_limit = time_limit
	if "penalty_time" in game: game.penalty_time = penalty_time
	
	# Добавляем на сцену (в отдельный CanvasLayer, чтобы UI не терялся из-за CanvasModulate/оверлеев)
	_add_minigame_to_scene(game)
	
	# Запускаем через контроллер (для паузы, курсора и таймера)
	if MinigameController and not MinigameController.is_active(game):
		var settings := MinigameSettings.new()
		settings.pause_game = false
		settings.show_mouse_cursor = true
		settings.block_player_movement = true
		settings.time_limit = time_limit
		settings.auto_finish_on_timeout = false
		MinigameController.start_minigame(game, settings)
	
	# Ловим момент закрытия игры
	game.tree_exited.connect(_on_minigame_closed)

func _on_minigame_closed() -> void:
	_current_minigame = null
	_update_visuals()
	
	# Если после игры лаба появилась в списке выполненных — успех
	if _is_lab_completed():
		complete_interaction() # Помечаем ноутбук как "пройденный" (для других цепочек)

func _handle_completed_interaction() -> void:
	if show_note_on_completed and completed_note_texture:
		UIMessage.show_note(completed_note_texture)
	else:
		UIMessage.show_text(completed_message)

# --- ВИЗУАЛ ---
func _on_dependency_finished() -> void:
	_update_visuals()

func _on_dependency_interaction_requested(_player: Node = null) -> void:
	if not unlock_on_dependency_interaction:
		return
	_dependency_override = true
	if not _is_enabled:
		is_enabled = true
	_update_visuals()

func _update_visuals() -> void:
	# Ноутбук "доступен" (светится), если зависимость выполнена.
	# (Базовый класс сам проверит зависимость при клике, но нам нужно обновить спрайт)
	var is_unlocked = true
	if dependency_object and not dependency_object.is_completed and not _dependency_override:
		is_unlocked = false
	if not _is_enabled:
		is_unlocked = false
	if _is_lab_completed():
		is_unlocked = false
	
	if is_unlocked:
		if _sprite and available_sprite: _sprite.texture = available_sprite
		if _available_light: _available_light.visible = true
		if _available_light_secondary: _available_light_secondary.visible = true
	else:
		if _sprite and locked_sprite: _sprite.texture = locked_sprite
		if _available_light: _available_light.visible = false
		if _available_light_secondary: _available_light_secondary.visible = false

func _can_interact() -> bool:
	return _is_enabled

func _show_prompt() -> void:
	if not _is_enabled:
		return
	super._show_prompt()

func _apply_enabled_state() -> void:
	set_prompts_enabled(_is_enabled)
	_update_visuals()

func _is_lab_completed() -> bool:
	return GameState.lab_done

func _is_dependency_satisfied() -> bool:
	if _dependency_override:
		return true
	if dependency_object == null:
		return true
	return dependency_object.is_completed
	
func _add_minigame_to_scene(minigame: Node) -> void:
	if minigame == null:
		return
	if MinigameController and MinigameController.has_method("attach_minigame"):
		MinigameController.attach_minigame(minigame)
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if parent:
		parent.add_child(minigame)
