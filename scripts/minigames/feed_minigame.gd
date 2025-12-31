extends CanvasLayer

signal minigame_finished

@export var food_needed: int = 5
@export var finish_delay: float = 2.0
@export var gamepad_cursor_speed: float = 800.0 # Скорость курсора с геймпада

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var andrey_sprite: TextureRect = $Control/AndreyFace
@onready var food_container: Node2D = $Control/FoodContainer
@onready var mouth_area: Area2D = $Control/AndreyFace/MouthArea

# Виртуальный курсор (картинка руки), если хочешь (необязательно)
# @onready var hand_cursor: Sprite2D = $Control/HandCursor 

var _eaten_count: int = 0
var _is_won: bool = false

func _ready() -> void:
	get_tree().paused = true
	
	mouth_area.body_entered.connect(_on_mouth_entered)
	mouth_area.area_entered.connect(_on_mouth_entered)
	
	if music_player.stream:
		music_player.play()
	
	# Скрываем системный курсор, если хочешь использовать свой спрайт
	# Input.mouse_mode = Input.MOUSE_MODE_HIDDEN 

func setup_game(andrey_texture: Texture2D, food_scene: PackedScene, count: int, music: AudioStream, win_sound: AudioStream) -> void:
	if andrey_texture:
		andrey_sprite.texture = andrey_texture
	
	food_needed = count
	
	if music:
		music_player.stream = music
	if win_sound:
		sfx_player.stream = win_sound

	for i in range(count):
		var food = food_scene.instantiate()
		food_container.add_child(food)
		
		# ИСПРАВЛЕНИЕ: Теперь спавним еду вокруг центра контейнера (0, 0),
		# а не относительно экрана. Разброс +- 50 пикселей.
		food.position = Vector2(
			randf_range(-50, 50), 
			randf_range(-50, 50)
		)
		
		food.eaten.connect(_on_food_eaten)

func _process(delta: float) -> void:
	_handle_gamepad_cursor(delta)

func _handle_gamepad_cursor(delta: float) -> void:
	# Получаем ввод с левого стика (стандартные UI действия или move_right/left)
	# Убедись, что у тебя настроены move_right, move_left, move_up, move_down в Input Map
	var joy_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if joy_vector.length() > 0.1:
		var current_mouse = get_viewport().get_mouse_position()
		var new_pos = current_mouse + joy_vector * gamepad_cursor_speed * delta
		
		# Ограничиваем курсор экраном
		var screen_rect = get_viewport().get_visible_rect().size
		new_pos.x = clamp(new_pos.x, 0, screen_rect.x)
		new_pos.y = clamp(new_pos.y, 0, screen_rect.y)
		
		# Двигаем системную мышь
		get_viewport().warp_mouse(new_pos)

func _on_mouth_entered(area: Area2D) -> void:
	if area.has_method("eat_me"):
		area.eat_me()

func _on_food_eaten() -> void:
	_eaten_count += 1
	if _eaten_count >= food_needed and not _is_won:
		_win()

func _win() -> void:
	_is_won = true
	music_player.stop()
	if sfx_player.stream:
		sfx_player.play()
	
	get_tree().create_timer(finish_delay).timeout.connect(_close_game)

func _close_game() -> void:
	get_tree().paused = false
	# Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Если скрывал курсор
	minigame_finished.emit()
	queue_free()

func _exit_tree() -> void:
	get_tree().paused = false
	
