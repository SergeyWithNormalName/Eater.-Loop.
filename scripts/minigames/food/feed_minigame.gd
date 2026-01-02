extends CanvasLayer

signal minigame_finished

@export var food_needed: int = 5
@export var finish_delay: float = 2.0
@export var gamepad_cursor_speed: float = 800.0

# Путь к сцене тарелки теперь жестко прописан в коде
var tarelka_scene = load("res://scenes/minigames/food/tarelka.tscn") 

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var andrey_sprite: TextureRect = $Control/AndreyFace
@onready var food_container: Node2D = $Control/FoodContainer
@onready var mouth_area: Area2D = $Control/AndreyFace/MouthArea

var sfx_player: AudioStreamPlayer 

var _eaten_count: int = 0
var _is_won: bool = false
var _base_viewport: Vector2
var _andrey_base_pos: Vector2
var _food_base_pos: Vector2
var _andrey_base_scale: Vector2
var _food_base_scale: Vector2

func _ready() -> void:
	if has_node("SFXPlayer"):
		sfx_player = $SFXPlayer
	else:
		sfx_player = AudioStreamPlayer.new()
		add_child(sfx_player)

	get_tree().paused = true
	if music_player.stream:
		music_player.play()
	
	_base_viewport = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	)
	_andrey_base_pos = andrey_sprite.position
	_food_base_pos = food_container.position
	_andrey_base_scale = andrey_sprite.scale
	_food_base_scale = food_container.scale
	
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func setup_game(andrey_texture: Texture2D, food_scene: PackedScene, count: int, music: AudioStream, win_sound: AudioStream) -> void:
	if andrey_texture:
		andrey_sprite.texture = andrey_texture
	
	food_needed = count
	
	if music:
		music_player.stream = music
	
	if win_sound:
		sfx_player.stream = win_sound

	# === ИСПРАВЛЕНИЕ 2: Одна тарелка для всей еды ===
	# Создаем тарелку ОДИН раз перед тем, как спавнить пельмени
	if tarelka_scene:
		var tarelka = tarelka_scene.instantiate()
		tarelka.name = "Tarelka"
		# === ИСПРАВЛЕНИЕ 1: Пельмени поверх тарелки ===
		# Добавляем тарелку в контейнер первой. В Godot это значит, что она будет в самом низу списка
		# и все объекты, добавленные позже (еда), окажутся ПОВЕРХ неё.
		food_container.add_child(tarelka)
		# Устанавливаем тарелку в центр контейнера
		tarelka.position = Vector2.ZERO 
	else:
		push_error("Не удалось найти сцену тарелки по пути res://scenes/minigames/food/tarelka.tscn")

	# Теперь спавним еду в цикле
	for i in range(count):
		# Генерируем случайную позицию для пельменей (разброс внутри тарелки)
		var spawn_pos = Vector2(randf_range(-120, 120), randf_range(-80, 80))
		
		var food = food_scene.instantiate()
		# Добавляем еду после тарелки, чтобы она была визуально выше
		food_container.add_child(food)
		food.position = spawn_pos
		
		if food.has_method("set_target_mouth"):
			food.set_target_mouth(mouth_area)
			
		food.eaten.connect(_on_food_eaten)

func _process(delta: float) -> void:
	_handle_gamepad_cursor(delta)

func _handle_gamepad_cursor(delta: float) -> void:
	var joy_vector = Input.get_vector("mg_cursor_left", "mg_cursor_right", "mg_cursor_up", "mg_cursor_down")
	
	if joy_vector.length() > 0.1:
		var current_mouse = get_viewport().get_mouse_position()
		var new_pos = current_mouse + joy_vector * gamepad_cursor_speed * delta
		
		var screen_rect = get_viewport().get_visible_rect().size
		new_pos.x = clamp(new_pos.x, 0, screen_rect.x)
		new_pos.y = clamp(new_pos.y, 0, screen_rect.y)
		
		get_viewport().warp_mouse(new_pos)

func _update_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if _base_viewport.x <= 0.0 or _base_viewport.y <= 0.0:
		return
	
	var scale_factor: float = min(viewport_size.x / _base_viewport.x, viewport_size.y / _base_viewport.y)
	var layout_offset: Vector2 = (viewport_size - _base_viewport * scale_factor) * 0.5
	
	andrey_sprite.position = layout_offset + _andrey_base_pos * scale_factor
	andrey_sprite.scale = _andrey_base_scale * scale_factor
	food_container.position = layout_offset + _food_base_pos * scale_factor
	food_container.scale = _food_base_scale * scale_factor

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
	minigame_finished.emit()
	
func _exit_tree() -> void:
	get_tree().paused = false
	if GameState.has_method("reset_dragging"):
		GameState.reset_dragging()
		
