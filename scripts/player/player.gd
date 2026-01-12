extends CharacterBody2D

## Скорость движения игрока.
@export var speed: float = 520.0

@export_group("Audio Settings")
## Набор звуков шагов.
@export var step_sounds: Array[AudioStream] # Звуки шагов
## Громкость шагов в дБ.
@export var step_volume: float = -10.0      # Громкость шагов в дБ
## Звук включения/выключения фонарика.
@export var flashlight_sound: AudioStream   # Звук фонарика

@export_group("Walk Animation")
## Папка с кадрами ходьбы.
@export var walk_frames_path: String = "res://textures/andreys_animations/walking"
## Префикс имени кадра (например, ezgif-frame-001.png).
@export var walk_frame_prefix: String = "ezgif-frame-"
## Количество кадров в последовательности.
@export var walk_frame_count: int = 15
## Длительность кадра в секундах.
@export var walk_frame_time: float = 0.08
## Стартовый кадр цикла (1-based).
@export var walk_loop_start_index: int = 1
## Конечный кадр цикла (1-based), -1 = последний кадр.
@export var walk_loop_end_index: int = -1
## Кадры (1-based), на которых звучат шаги.
@export var step_frame_indices: Array[int] = [2, 9]

var keys: Dictionary = {}

# Ссылки на узлы
@onready var pivot: Node2D = get_node_or_null("Pivot") as Node2D
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var flashlight: PointLight2D = null

var _facing_dir: float = 1.0
var _pivot_base_scale: Vector2 = Vector2.ONE
var _sprite_base_scale: Vector2 = Vector2.ONE
var _flashlight_base_scale: Vector2 = Vector2.ONE
var _flashlight_base_offset: Vector2 = Vector2.ZERO
var _idle_texture: Texture2D = null
var _walk_frames: Array[Texture2D] = []
var _walk_frame_index: int = 0
var _walk_frame_timer: float = 0.0
var _is_walking: bool = false
var _sprite_anim_scale: Vector2 = Vector2.ONE
var _sprite_under_pivot: bool = false
var _walk_loop_start: int = 0
var _walk_loop_end: int = 0
var _step_frame_lookup: Dictionary = {}

# Переменные для аудио
var _step_player: AudioStreamPlayer 
var _flashlight_player: AudioStreamPlayer

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	
	# --- ИЗМЕНЕНИЕ: Создаем два отдельных аудио-плеера ---
	_step_player = AudioStreamPlayer.new()
	add_child(_step_player)
	
	_flashlight_player = AudioStreamPlayer.new()
	add_child(_flashlight_player)
	# -----------------------------------------------------
	
	if pivot and pivot.has_node("PointLight2D"):
		flashlight = pivot.get_node("PointLight2D") as PointLight2D
	else:
		flashlight = get_node_or_null("PointLight2D") as PointLight2D

	if sprite == null and pivot and pivot.has_node("Sprite2D"):
		sprite = pivot.get_node("Sprite2D") as Sprite2D
	
	if pivot:
		_pivot_base_scale = pivot.scale
	if sprite:
		_sprite_base_scale = sprite.scale
		_idle_texture = sprite.texture
		_sprite_under_pivot = pivot != null and pivot.is_ancestor_of(sprite)
		_load_walk_frames()
	if flashlight:
		_flashlight_base_scale = flashlight.scale
		_flashlight_base_offset = flashlight.offset
		
		# --- ИЗМЕНЕНИЕ: Выключаем фонарик при старте ---
		flashlight.enabled = false 
	
	_apply_facing()

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if abs(direction) < 0.1:
		direction = 0.0
	
	velocity.x = direction * speed
	velocity.y = 0
	move_and_slide()

	# ЛОГИКА ПОВОРОТА
	if direction != 0:
		_facing_dir = sign(direction)
		_apply_facing()

	_update_walk_animation(delta, direction)

func _play_step_sound() -> void:
	if step_sounds.is_empty():
		return

	# Используем отдельный плеер для шагов
	_step_player.stream = step_sounds.pick_random()
	_step_player.volume_db = step_volume
	_step_player.pitch_scale = randf_range(0.9, 1.1)
	_step_player.play()

func _apply_facing() -> void:
	if pivot:
		pivot.scale = Vector2(abs(_pivot_base_scale.x) * _facing_dir, _pivot_base_scale.y)
	if sprite:
		var x_scale: float = absf(_sprite_base_scale.x) * _sprite_anim_scale.x
		var y_scale: float = _sprite_base_scale.y * _sprite_anim_scale.y
		if not _sprite_under_pivot:
			x_scale *= _facing_dir
		sprite.scale = Vector2(x_scale, y_scale)
	if flashlight:
		if pivot == null:
			flashlight.scale = Vector2(abs(_flashlight_base_scale.x) * _facing_dir, _flashlight_base_scale.y)
			flashlight.offset = _flashlight_base_offset

func _load_walk_frames() -> void:
	_walk_frames.clear()
	if walk_frame_count <= 0:
		return
	for i in range(1, walk_frame_count + 1):
		var path := "%s/%s%03d.png" % [walk_frames_path, walk_frame_prefix, i]
		var frame := load(path) as Texture2D
		if frame:
			_walk_frames.append(frame)
		else:
			push_warning("Missing walk frame: %s" % path)
	_update_walk_loop_bounds()
	_update_step_frame_lookup()

func _update_walk_loop_bounds() -> void:
	_walk_loop_start = 0
	_walk_loop_end = -1
	if _walk_frames.is_empty():
		return
	var max_index := _walk_frames.size() - 1
	_walk_loop_start = clampi(walk_loop_start_index, 0, max_index)
	var end_index := walk_loop_end_index
	if end_index < 0:
		end_index = max_index
	_walk_loop_end = clampi(end_index, _walk_loop_start, max_index)

func _update_step_frame_lookup() -> void:
	_step_frame_lookup.clear()
	if _walk_frames.is_empty():
		return
	for index in step_frame_indices:
		if index <= 0:
			continue
		var frame_index := index - 1
		if frame_index >= 0 and frame_index < _walk_frames.size():
			_step_frame_lookup[frame_index] = true

func _maybe_play_step_for_frame(frame_index: int) -> void:
	if _step_frame_lookup.is_empty():
		return
	if _step_frame_lookup.has(frame_index):
		_play_step_sound()

func _calc_texture_scale(texture: Texture2D) -> Vector2:
	if _idle_texture == null or texture == null:
		return Vector2.ONE
	var idle_size := _idle_texture.get_size()
	var tex_size := texture.get_size()
	if idle_size.y <= 0.0 or tex_size.y <= 0.0:
		return Vector2.ONE
	var ratio := idle_size.y / tex_size.y
	return Vector2(ratio, ratio)

func _set_sprite_texture(texture: Texture2D) -> void:
	if sprite == null or texture == null:
		return
	sprite.texture = texture
	_sprite_anim_scale = _calc_texture_scale(texture)
	_apply_facing()

func _update_walk_animation(delta: float, direction: float) -> void:
	if sprite == null or _walk_frames.is_empty():
		return
	if walk_frame_time <= 0.0:
		return
	if _walk_loop_end < 0:
		return
	var is_moving := direction != 0.0
	if is_moving:
		if not _is_walking:
			_is_walking = true
			_walk_frame_index = _walk_loop_start
			_walk_frame_timer = 0.0
			_set_sprite_texture(_walk_frames[_walk_frame_index])
			_maybe_play_step_for_frame(_walk_frame_index)
		_walk_frame_timer += delta
		while _walk_frame_timer >= walk_frame_time:
			_walk_frame_timer -= walk_frame_time
			if _walk_frame_index >= _walk_loop_end:
				_walk_frame_index = _walk_loop_start
			else:
				_walk_frame_index += 1
			_set_sprite_texture(_walk_frames[_walk_frame_index])
			_maybe_play_step_for_frame(_walk_frame_index)
	else:
		if _is_walking:
			_is_walking = false
			_walk_frame_timer = 0.0
			_walk_frame_index = _walk_loop_start
			if _idle_texture:
				_set_sprite_texture(_idle_texture)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_flashlight"):
		if flashlight:
			flashlight.enabled = !flashlight.enabled
			
			# Используем отдельный плеер для фонарика
			if flashlight_sound:
				_flashlight_player.stream = flashlight_sound
				_flashlight_player.volume_db = 0.0 # Громкость фонарика стандартная
				_flashlight_player.pitch_scale = 1.0
				_flashlight_player.play()

# ===== Работа с ключами =====
func add_key(key_id: String) -> void:
	if key_id == "": return
	keys[key_id] = true

func has_key(key_id: String) -> bool:
	if key_id == "": return false
	return keys.has(key_id)

func remove_key(key_id: String) -> void:
	if keys.has(key_id): keys.erase(key_id)
	
