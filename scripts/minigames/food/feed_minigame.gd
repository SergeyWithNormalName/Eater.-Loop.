extends CanvasLayer

signal minigame_finished

## Сколько еды нужно скормить для победы.
@export var food_needed: int = 5
## Задержка перед завершением мини-игры.
@export var finish_delay: float = 2.0
## Скорость курсора геймпада.
@export var gamepad_cursor_speed: float = 800.0
## Звук поедания.
@export var eat_sound: AudioStream
## Фон мини-игры.
@export var background_texture: Texture2D
## Громкость музыки в дБ.
@export_range(-40.0, 6.0, 0.1) var music_volume_db: float = -12.0
## Длительность затухания фоновой музыки при старте мини-игры.
@export_range(0.0, 5.0, 0.1) var music_suspend_fade_time: float = 0.3

const DEFAULT_BG: Texture2D = preload("res://textures/FonForFood.png")
const DEFAULT_MUSIC: AudioStream = preload("res://audio/MusicForEat.mp3")
const DEFAULT_EAT: AudioStream = preload("res://audio/AndreyEating/Nam-nam_1.wav")
const DEFAULT_WIN: AudioStream = preload("res://audio/AndreyEating/Poel_1.wav")

# Путь к сцене тарелки теперь жестко прописан в коде
var tarelka_scene = load("res://scenes/minigames/food/tarelka.tscn") 

@onready var backfon: Sprite2D = $Control/BackFon
@onready var dim_rect: ColorRect = $Control/ColorRect
@onready var andrey_sprite: TextureRect = $Control/AndreyFace
@onready var food_container: Node2D = $Control/FoodContainer
@onready var mouth_area: Area2D = $Control/AndreyFace/MouthArea

var sfx_player: AudioStreamPlayer 
var eat_sfx_player: AudioStreamPlayer

var _eaten_count: int = 0
var _is_won: bool = false
var _base_viewport: Vector2
var _selected_music: AudioStream = null

func _ready() -> void:
	add_to_group("minigame_ui")
	if has_node("SoundsPlayer"):
		sfx_player = $SoundsPlayer
	else:
		sfx_player = AudioStreamPlayer.new()
		add_child(sfx_player)
	sfx_player.bus = "Sounds"
	
	eat_sfx_player = AudioStreamPlayer.new()
	eat_sfx_player.bus = "Sounds"
	eat_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(eat_sfx_player)

	_selected_music = DEFAULT_MUSIC
	_start_minigame_session()
	
	_base_viewport = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	)
	_apply_background_layout()

func setup_game(andrey_texture: Texture2D, food_scene: PackedScene, count: int, music: AudioStream, win_sound: AudioStream, eat_sound_override: AudioStream = null, bg_override: Texture2D = null) -> void:
	if andrey_texture:
		andrey_sprite.texture = andrey_texture
	
	food_needed = count
	
	var selected_music: AudioStream = music if music else DEFAULT_MUSIC
	if selected_music:
		_selected_music = selected_music
		if MinigameController:
			MinigameController.update_minigame_music(selected_music, music_volume_db, music_suspend_fade_time)
	
	var selected_win: AudioStream = win_sound if win_sound else DEFAULT_WIN
	if selected_win:
		sfx_player.stream = selected_win
	
	var selected_eat: AudioStream = eat_sound_override if eat_sound_override else (eat_sound if eat_sound else DEFAULT_EAT)
	if selected_eat:
		eat_sfx_player.stream = selected_eat
	
	var selected_bg: Texture2D = bg_override if bg_override else (background_texture if background_texture else backfon.texture)
	if selected_bg == null:
		selected_bg = DEFAULT_BG
	if selected_bg:
		backfon.texture = selected_bg
		_apply_background_layout()

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

func _process(_delta: float) -> void:
	pass

func _apply_background_layout() -> void:
	if backfon == null or backfon.texture == null:
		return
	if _base_viewport.x <= 0.0 or _base_viewport.y <= 0.0:
		return
	
	var tex_size := backfon.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	
	var cover_scale: float = max(_base_viewport.x / tex_size.x, _base_viewport.y / tex_size.y)
	backfon.scale = Vector2(cover_scale, cover_scale)
	backfon.position = _base_viewport * 0.5

func _on_food_eaten() -> void:
	_eaten_count += 1
	if eat_sfx_player.stream:
		eat_sfx_player.play()
	if _eaten_count >= food_needed and not _is_won:
		_win()

func _win() -> void:
	_is_won = true
	if MinigameController:
		MinigameController.stop_minigame_music(music_suspend_fade_time)
	
	if sfx_player.stream:
		sfx_player.play()
	
	get_tree().create_timer(finish_delay).timeout.connect(_close_game)

func _close_game() -> void:
	if MinigameController:
		MinigameController.finish_minigame(self, true)
	minigame_finished.emit()
	
func _exit_tree() -> void:
	if MinigameController:
		if MinigameController.is_active(self):
			MinigameController.finish_minigame(self, false)
	if GameState.has_method("reset_dragging"):
		GameState.reset_dragging()

func _start_minigame_session() -> void:
	if MinigameController == null:
		return
	MinigameController.start_minigame(self, {
		"pause_game": true,
		"enable_gamepad_cursor": true,
		"gamepad_cursor_speed": gamepad_cursor_speed,
		"music_stream": _selected_music,
		"music_volume_db": music_volume_db,
		"music_fade_time": music_suspend_fade_time,
		"auto_finish_on_timeout": false,
		"stop_music_on_finish": false
	})
		
