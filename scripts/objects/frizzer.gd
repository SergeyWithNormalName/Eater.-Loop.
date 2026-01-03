extends Area2D

# --- Настройки мини-игры ---
@export_group("Minigame Settings")
@export var minigame_scene: PackedScene 
@export var food_scene: PackedScene     
@export var andrey_face: Texture2D      
@export var food_count: int = 5         
@export var bg_music: AudioStream       
@export var win_sound: AudioStream      
@export var eat_sound: AudioStream
@export var background_texture: Texture2D
@export var required_lab_id: String = ""
@export var required_cycle: int = 0
@export_multiline var locked_message: String = "Точно! Сначала я должен доделать лабораторную работу"

# --- Настройки звуков ---
@export_group("Sounds")
@export var open_sound: AudioStream # Сюда перетащите звук открытия двери

# --- Внутренние переменные ---
var player_inside: bool = false
var _is_interacting: bool = false
var _current_minigame: Node = null 
var _sfx_player: AudioStreamPlayer # Плеер создается кодом

func _ready() -> void:
	input_pickable = false
	
	# Безопасное подключение сигналов входа/выхода
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Создаем аудио-плеер динамически, чтобы не добавлять его вручную в сцену
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

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
	if _is_locked_by_lab():
		UIMessage.show_text(locked_message)
		return

	if GameState.ate_this_cycle:
		UIMessage.show_text("Я уже наелся и хочу спать")
		return

	_is_interacting = true

	# --- ВОСПРОИЗВЕДЕНИЕ ЗВУКА ОТКРЫТИЯ ---
	if open_sound:
		_sfx_player.stream = open_sound
		_sfx_player.play()
	# --------------------------------------

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
	_current_minigame = game 
	get_tree().root.add_child(game)
	
	if game.has_method("setup_game"):
		# Передаем win_sound в мини-игру
		game.setup_game(andrey_face, food_scene, food_count, bg_music, win_sound, eat_sound, background_texture)
	
	game.minigame_finished.connect(_on_minigame_finished)

func _on_minigame_finished() -> void:
	# 1. Сначала затемняем экран
	await UIMessage.fade_out(0.4)
	
	# 2. Удаляем мини-игру
	if _current_minigame != null:
		_current_minigame.queue_free()
		_current_minigame = null
	
	# 3. Обновляем логику игры (Андрей поел)
	_complete_feeding()
	
	# 4. Проявляем экран обратно
	await UIMessage.fade_in(0.4)
	_is_interacting = false

func _complete_feeding() -> void:
	GameState.mark_ate()
	UIMessage.show_text("Вкуснятина")
	
	var current_level = get_tree().current_scene
	if current_level.has_method("on_fed_andrey"):
		current_level.on_fed_andrey()

func _is_locked_by_lab() -> bool:
	if required_lab_id == "":
		return false
	if required_cycle > 0 and GameState.cycle != required_cycle:
		return false
	return not GameState.completed_labs.has(required_lab_id)
		
		
