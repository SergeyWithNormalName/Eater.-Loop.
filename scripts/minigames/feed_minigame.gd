extends CanvasLayer

signal minigame_finished

@export var food_needed: int = 5
@export var finish_delay: float = 2.0 # Сколько ждем после победы перед закрытием

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var andrey_sprite: TextureRect = $Control/AndreyFace
@onready var food_container: Node2D = $Control/FoodContainer
@onready var mouth_area: Area2D = $Control/AndreyFace/MouthArea

var _eaten_count: int = 0
var _is_won: bool = false

func _ready() -> void:
	# ВАЖНО: Ставим игру на паузу, чтобы в основном мире ничего не происходило
	get_tree().paused = true
	
	# Подключаем сигнал входа в рот
	mouth_area.body_entered.connect(_on_mouth_entered)
	# Для Area2D еды (если еда — это Area2D, используем area_entered)
	mouth_area.area_entered.connect(_on_mouth_entered)
	
	if music_player.stream:
		music_player.play()

func setup_game(andrey_texture: Texture2D, food_scene: PackedScene, count: int, music: AudioStream, win_sound: AudioStream) -> void:
	# Настройка извне (от холодильника)
	if andrey_texture:
		andrey_sprite.texture = andrey_texture
	
	food_needed = count
	
	if music:
		music_player.stream = music
	if win_sound:
		sfx_player.stream = win_sound

	# Спавним еду в случайных местах внутри контейнера
	# Предполагаем, что FoodContainer находится где-то сбоку
	for i in range(count):
		var food = food_scene.instantiate()
		food_container.add_child(food)
		# Случайный разброс позиции (настрой под свой UI)
		food.position = Vector2(randf_range(0, 200), randf_range(0, 300))
		food.eaten.connect(_on_food_eaten)

func _on_mouth_entered(area: Area2D) -> void:
	# Если то, что вошло в рот, имеет метод eat_me
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
	
	# Ждем окончания звука или таймера
	var timer = get_tree().create_timer(finish_delay)
	timer.timeout.connect(_close_game)

func _close_game() -> void:
	# Снимаем паузу
	get_tree().paused = false
	minigame_finished.emit()
	queue_free()

func _exit_tree() -> void:
	# На всякий случай, если игру закроют аварийно
	get_tree().paused = false
