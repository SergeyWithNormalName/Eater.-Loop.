extends Area2D

# Настройки для КОНКРЕТНОГО уровня в Инспекторе
@export_group("Minigame Settings")
@export var minigame_scene: PackedScene # Сюда перетащишь сцену мини-игры (FeedMiniGame)
@export var food_scene: PackedScene     # Сюда перетащишь сцену еды (FoodItem)
@export var andrey_face: Texture2D      # Лицо Андрея для этого уровня
@export var food_count: int = 5         # Сколько нужно съесть
@export var bg_music: AudioStream       # Музыка фона
@export var win_sound: AudioStream      # Звук победы ("рыг" или "вкусно")

var player_inside: bool = false

func _ready() -> void:
	input_pickable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside:
		return
	if event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	if GameState.ate_this_cycle:
		UIMessage.show_text("Ты уже ел.")
		return

	# Если мини-игра не настроена, просто кормим (как раньше)
	if minigame_scene == null or food_scene == null:
		push_warning("Frizzer: Minigame scene or Food scene is missing!")
		_complete_feeding()
		return

	_start_minigame()

func _start_minigame() -> void:
	# Создаем игру
	var game = minigame_scene.instantiate()
	# Добавляем в корень сцены (выше текущего уровня), чтобы перекрыла всё
	get_tree().root.add_child(game)
	
	# Настраиваем
	if game.has_method("setup_game"):
		game.setup_game(andrey_face, food_scene, food_count, bg_music, win_sound)
	
	# Подписываемся на окончание
	game.minigame_finished.connect(_on_minigame_finished)

func _on_minigame_finished() -> void:
	_complete_feeding()

func _complete_feeding() -> void:
	GameState.mark_ate()
	UIMessage.show_text("Андрей поел.")
	
	# === ЛАЗЕЙКА НА БУДУЩЕЕ ===
	# Проверяем, есть ли у уровня метод "on_fed_andrey" и вызываем его
	var current_level = get_tree().current_scene
	if current_level.has_method("on_fed_andrey"):
		current_level.on_fed_andrey()
		
