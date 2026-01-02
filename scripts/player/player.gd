extends CharacterBody2D

@export var speed: float = 520.0

@export_group("Audio Settings")
@export var step_sounds: Array[AudioStream] # Сюда добавьте звуки шагов
@export var step_interval: float = 0.35     # Частота звука шагов
@export var step_volume: float = -10.0 # Громкость шагов в дБ (чем меньше число, тем тише)
@export var flashlight_sound: AudioStream   # Звук фонарика

var keys: Dictionary = {}

# Ссылки на узлы
@onready var pivot: Node2D = get_node_or_null("Pivot") as Node2D
@onready var sprite: Node2D = get_node_or_null("Sprite2D") as Node2D
@onready var flashlight: PointLight2D = null

var _facing_dir: float = 1.0
var _pivot_base_scale: Vector2 = Vector2.ONE
var _sprite_base_scale: Vector2 = Vector2.ONE
var _flashlight_base_scale: Vector2 = Vector2.ONE
var _flashlight_base_offset: Vector2 = Vector2.ZERO

# Переменные для аудио
var _step_timer: float = 0.0
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	
	# Создаем аудио-плеер
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	
	if pivot and pivot.has_node("PointLight2D"):
		flashlight = pivot.get_node("PointLight2D") as PointLight2D
	else:
		flashlight = get_node_or_null("PointLight2D") as PointLight2D
	
	if pivot:
		_pivot_base_scale = pivot.scale
	if sprite:
		_sprite_base_scale = sprite.scale
	if flashlight:
		_flashlight_base_scale = flashlight.scale
		_flashlight_base_offset = flashlight.offset
	
	_apply_facing()

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if abs(direction) < 0.1:
		direction = 0.0
	
	velocity.x = direction * speed
	velocity.y = 0
	move_and_slide()

	# --- ЛОГИКА ШАГОВ (ИСПРАВЛЕННАЯ) ---
	# Убрали проверку is_on_floor(), так как гравитации нет
	if direction != 0:
		_step_timer -= delta
		if _step_timer <= 0:
			_play_step_sound()
			_step_timer = step_interval
	else:
		# Сброс таймера, чтобы первый шаг звучал сразу при начале движения
		_step_timer = 0.05
	# -----------------------------------

	# ЛОГИКА ПОВОРОТА
	if direction != 0:
		_facing_dir = sign(direction)
		_apply_facing()

func _play_step_sound() -> void:
	if step_sounds.is_empty():
		return

	_sfx_player.stream = step_sounds.pick_random()
	_sfx_player.volume_db = step_volume # Устанавливаем громкость перед воспроизведением
	_sfx_player.pitch_scale = randf_range(0.9, 1.1)
	_sfx_player.play() 

func _apply_facing() -> void:
	if pivot:
		pivot.scale = Vector2(abs(_pivot_base_scale.x) * _facing_dir, _pivot_base_scale.y)
		return
	
	if sprite:
		sprite.scale = Vector2(abs(_sprite_base_scale.x) * _facing_dir, _sprite_base_scale.y)
	if flashlight:
		flashlight.scale = Vector2(abs(_flashlight_base_scale.x) * _facing_dir, _flashlight_base_scale.y)
		flashlight.offset = _flashlight_base_offset

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_flashlight"):
		if flashlight:
			flashlight.enabled = !flashlight.enabled
			if flashlight_sound:
				_sfx_player.pitch_scale = 1.0
				_sfx_player.stream = flashlight_sound
				_sfx_player.play()

# ===== Работа с ключами =====
func add_key(key_id: String) -> void:
	if key_id == "": return
	keys[key_id] = true

func has_key(key_id: String) -> bool:
	if key_id == "": return false
	return keys.has(key_id)

func remove_key(key_id: String) -> void:
	if keys.has(key_id): keys.erase(key_id)
	
