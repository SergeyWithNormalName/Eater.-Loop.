extends Area2D

@export_group("Minigame Settings")
@export var minigame_scene: PackedScene 
@export var food_scene: PackedScene     
@export var andrey_face: Texture2D      
@export var food_count: int = 5         
@export var bg_music: AudioStream       
@export var win_sound: AudioStream      

var player_inside: bool = false
var _is_interacting: bool = false
var _current_minigame: Node = null # Храним ссылку на текущую игру

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
	if _is_interacting: return
	if not player_inside: return
	
	if event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	if GameState.ate_this_cycle:
		UIMessage.show_text("Ты уже ел.")
		return

	_is_interacting = true

	if minigame_scene == null or food_scene == null:
		push_warning("Frizzer: Minigame scene or Food scene is missing!")
		_complete_feeding()
		_is_interacting = false
		return

	await UIMessage.fade_out(0.3)
	_start_minigame()
	await UIMessage.fade_in(0.3)

func _start_minigame() -> void:
	var game = minigame_scene.instantiate()
	_current_minigame = game # Запоминаем ссылку
	get_tree().root.add_child(game)
	
	if game.has_method("setup_game"):
		game.setup_game(andrey_face, food_scene, food_count, bg_music, win_sound)
	
	game.minigame_finished.connect(_on_minigame_finished)

func _on_minigame_finished() -> void:
	# 1. Сначала затемняем экран (Андрей всё еще виден!)
	await UIMessage.fade_out(0.4)
	
	# 2. Теперь, когда темно, удаляем мини-игру
	if _current_minigame != null:
		_current_minigame.queue_free()
		_current_minigame = null
	
	# 3. Обновляем логику игры
	_complete_feeding()
	
	# 4. Проявляем экран обратно
	await UIMessage.fade_in(0.4)
	_is_interacting = false

func _complete_feeding() -> void:
	GameState.mark_ate()
	UIMessage.show_text("Андрей поел.")
	
	var current_level = get_tree().current_scene
	if current_level.has_method("on_fed_andrey"):
		current_level.on_fed_andrey()
		
		
