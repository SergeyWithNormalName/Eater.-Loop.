extends CharacterBody2D

signal player_made_sound
signal flashlight_recharged
signal flashlight_activation_denied(charge_ratio: float)

## Скорость движения игрока.
@export var speed: float = 415.0

@export_group("Бег и выносливость")
## Разрешить бег.
@export var allow_running: bool = true
## Множитель скорости при беге.
@export var run_speed_multiplier: float = 1.8
## Максимальная выносливость.
@export var stamina_max: float = 5.0
## Расход выносливости в секунду при беге.
@export var stamina_drain_rate: float = 1.0
## Восстановление выносливости в секунду.
@export var stamina_recovery_rate: float = 0.6
## Задержка перед восстановлением выносливости (сек).
@export var stamina_recovery_delay: float = 2.0
## Минимальная выносливость для старта бега.
@export var stamina_min_to_run: float = 0.2

@export_group("Audio Settings")
## Набор звуков шагов.
@export var step_sounds: Array[AudioStream] = []
## Громкость шагов в дБ.
@export var step_volume: float = -10.0
## Звук включения/выключения фонарика.
@export var flashlight_sound: AudioStream
## Звук полной зарядки фонарика (опционально).
@export var flashlight_recharged_sound: AudioStream
## Звук попытки включить незаряженный фонарик (опционально).
@export var flashlight_denied_sound: AudioStream

@export_group("Фонарик")
## Время непрерывной работы фонарика при полном заряде (сек).
@export var flashlight_use_duration: float = 5.0
## Время полной перезарядки фонарика (сек).
@export var flashlight_recharge_duration: float = 5.0
## Задержка перед началом перезарядки фонарика (сек).
@export var flashlight_recharge_delay: float = 1.0

@export_group("Walk Animation")
## Имя анимации ходьбы в AnimatedSprite2D.
@export var walk_animation: StringName = &"walk"
## Имя анимации покоя (если нет, будет стоять на первом кадре walk).
@export var idle_animation: StringName = &"idle"
## Длительность кадра в секундах.
@export var walk_frame_time: float = 0.08
## Стартовый кадр цикла (1-based).
@export var walk_loop_start_index: int = 1
## Конечный кадр цикла (1-based), -1 = последний кадр.
@export var walk_loop_end_index: int = -1
## Номера кадров (начиная с 1), на которых должен звучать шаг.
## Например: [2, 9] означает, что звук будет на 2-м и 9-м кадре анимации.
@export var step_frame_indices: Array[int] = [2, 9]

var keys: Dictionary = {}

# Ссылки на узлы
@onready var pivot: Node2D = get_node_or_null("Pivot") as Node2D
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var flashlight: PointLight2D = null
var step_audio: StepAudioComponent = null

# Внутренние переменные
var _facing_dir: float = 1.0
var _pivot_base_scale: Vector2 = Vector2.ONE
var _sprite_base_scale: Vector2 = Vector2.ONE
var _flashlight_base_scale: Vector2 = Vector2.ONE
var _flashlight_base_offset: Vector2 = Vector2.ZERO
var _idle_texture: Texture2D = null
var _is_walking: bool = false
var _is_running: bool = false
var _sprite_anim_scale: Vector2 = Vector2.ONE
var _sprite_under_pivot: bool = false
var _walk_loop_start: int = 0
var _walk_loop_end: int = 0
var _stamina: float = 0.0
var _flashlight_charge: float = 0.0
var _time_since_flashlight_use: float = 0.0
var _time_since_run: float = 0.0
var _adjusting_frame: bool = false
var _movement_blocked: bool = false

# Переменные для аудио
var _flashlight_player: AudioStreamPlayer
var _flashlight_recharged_player: AudioStreamPlayer
var _flashlight_denied_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("player")
	
	# --- Настройка аудио ---
	_flashlight_player = AudioStreamPlayer.new()
	_flashlight_player.bus = "Sounds"
	add_child(_flashlight_player)
	_flashlight_recharged_player = AudioStreamPlayer.new()
	_flashlight_recharged_player.bus = "Sounds"
	add_child(_flashlight_recharged_player)
	_flashlight_denied_player = AudioStreamPlayer.new()
	_flashlight_denied_player.bus = "Sounds"
	add_child(_flashlight_denied_player)
	# -----------------------
	
	# Инициализация узлов
	if pivot and pivot.has_node("PointLight2D"):
		flashlight = pivot.get_node("PointLight2D") as PointLight2D
	else:
		flashlight = get_node_or_null("PointLight2D") as PointLight2D

	if sprite == null and pivot and pivot.has_node("AnimatedSprite2D"):
		sprite = pivot.get_node("AnimatedSprite2D") as AnimatedSprite2D
	
	if pivot:
		_pivot_base_scale = pivot.scale
	
	if sprite:
		_sprite_base_scale = sprite.scale
		_sprite_under_pivot = pivot != null and pivot.is_ancestor_of(sprite)
		_setup_animations()
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		step_audio = _resolve_step_audio_component()
		if step_audio:
			step_audio.configure(step_sounds, step_volume, step_frame_indices, walk_animation)
			step_audio.step_triggered.connect(_on_step_triggered)
	
	if flashlight:
		_flashlight_base_scale = flashlight.scale
		_flashlight_base_offset = flashlight.offset
		flashlight.enabled = false 
	
	_stamina = stamina_max
	_flashlight_charge = max(0.0, flashlight_use_duration)
	_time_since_flashlight_use = max(0.0, flashlight_recharge_delay)
	_apply_facing()
	_connect_minigame_controller()

func _connect_minigame_controller() -> void:
	if MinigameController == null:
		return
	if MinigameController.has_signal("minigame_started") and not MinigameController.minigame_started.is_connected(_on_minigame_state_changed):
		MinigameController.minigame_started.connect(_on_minigame_state_changed)
	if MinigameController.has_signal("minigame_finished") and not MinigameController.minigame_finished.is_connected(_on_minigame_state_changed):
		MinigameController.minigame_finished.connect(_on_minigame_state_changed)
	if MinigameController.has_method("should_block_player_movement"):
		_movement_blocked = bool(MinigameController.should_block_player_movement())

func _on_minigame_state_changed(_minigame: Node, _success: bool = true) -> void:
	if MinigameController and MinigameController.has_method("should_block_player_movement"):
		_movement_blocked = bool(MinigameController.should_block_player_movement())
	else:
		_movement_blocked = false

func _physics_process(delta: float) -> void:
	if _is_movement_blocked():
		_is_running = _resolve_running_state(delta, 0.0)
		velocity = Vector2.ZERO
		move_and_slide()
		_update_walk_animation(delta, 0.0)
		_update_flashlight_charge(delta)
		return
	var direction := Input.get_axis("move_left", "move_right")
	if _is_screen_dark():
		direction = 0.0
	
	# Небольшая мертвая зона для аналоговых стиков
	if abs(direction) < 0.1:
		direction = 0.0
	
	_is_running = _resolve_running_state(delta, direction)
	var current_speed := speed * (run_speed_multiplier if _is_running else 1.0)
	velocity.x = direction * current_speed
	velocity.y = 0
	move_and_slide()

	# Логика поворота персонажа
	if direction != 0:
		_facing_dir = sign(direction)
		_apply_facing()

	# Обновление анимации
	_update_walk_animation(delta, direction)
	_update_flashlight_charge(delta)

func _is_movement_blocked() -> bool:
	return _movement_blocked

func _is_screen_dark() -> bool:
	if UIMessage == null:
		return false
	if UIMessage.has_method("is_screen_dark"):
		return bool(UIMessage.call("is_screen_dark"))
	return false

func _resolve_running_state(delta: float, direction: float) -> bool:
	if not allow_running:
		_time_since_run += delta
		_try_restore_stamina(delta)
		return false

	if direction == 0.0:
		_time_since_run += delta
		_try_restore_stamina(delta)
		return false

	if stamina_max <= 0.0:
		var unlimited_run := Input.is_action_pressed("run")
		if unlimited_run:
			_time_since_run = 0.0
		else:
			_time_since_run += delta
		return unlimited_run

	if Input.is_action_pressed("run") and _stamina > stamina_min_to_run:
		_time_since_run = 0.0
		_drain_stamina(delta)
		return true

	_time_since_run += delta
	_try_restore_stamina(delta)
	return false

func _drain_stamina(delta: float) -> void:
	if stamina_drain_rate <= 0.0:
		return
	_stamina = max(0.0, _stamina - stamina_drain_rate * delta)

func _restore_stamina(delta: float) -> void:
	if stamina_recovery_rate <= 0.0:
		return
	if stamina_max <= 0.0:
		return
	_stamina = min(stamina_max, _stamina + stamina_recovery_rate * delta)

func _try_restore_stamina(delta: float) -> void:
	if _time_since_run < stamina_recovery_delay:
		return
	_restore_stamina(delta)

func get_stamina_ratio() -> float:
	if stamina_max <= 0.0:
		return 1.0
	return clamp(_stamina / stamina_max, 0.0, 1.0)

func get_flashlight_charge_ratio() -> float:
	if flashlight_use_duration <= 0.0:
		return 1.0
	return clampf(_flashlight_charge / flashlight_use_duration, 0.0, 1.0)

func is_running() -> bool:
	return _is_running

func is_flashlight_enabled() -> bool:
	return flashlight != null and flashlight.enabled

func _update_flashlight_charge(delta: float) -> void:
	if flashlight == null:
		return

	var max_charge: float = maxf(0.0, flashlight_use_duration)
	_flashlight_charge = clampf(_flashlight_charge, 0.0, max_charge)
	if max_charge <= 0.0:
		return

	if flashlight.enabled:
		_time_since_flashlight_use = 0.0
		_flashlight_charge = maxf(0.0, _flashlight_charge - delta)
		if _flashlight_charge <= 0.0:
			_set_flashlight_enabled(false)
		return

	_time_since_flashlight_use += delta
	if _time_since_flashlight_use < maxf(0.0, flashlight_recharge_delay):
		return

	if flashlight_recharge_duration <= 0.0:
		var was_below_full_instant := _flashlight_charge < max_charge
		_flashlight_charge = max_charge
		if was_below_full_instant:
			_emit_flashlight_recharged()
		return

	var prev_charge: float = _flashlight_charge
	var recharge_rate: float = max_charge / flashlight_recharge_duration
	_flashlight_charge = minf(max_charge, _flashlight_charge + recharge_rate * delta)
	if prev_charge < max_charge and _flashlight_charge >= max_charge:
		_emit_flashlight_recharged()

func _toggle_flashlight() -> void:
	if flashlight == null:
		return
	if flashlight.enabled:
		_set_flashlight_enabled(false)
		return
	if _can_enable_flashlight():
		_set_flashlight_enabled(true)
		return
	_emit_flashlight_activation_denied()

func _can_enable_flashlight() -> bool:
	if flashlight_use_duration <= 0.0:
		return true
	var max_charge: float = maxf(0.0, flashlight_use_duration)
	return _flashlight_charge >= max_charge

func _set_flashlight_enabled(enabled_state: bool) -> void:
	if flashlight == null:
		return
	if flashlight.enabled == enabled_state:
		return
	flashlight.enabled = enabled_state
	_play_flashlight_toggle_sound()

func _play_flashlight_toggle_sound() -> void:
	if flashlight_sound == null:
		return
	_flashlight_player.stream = flashlight_sound
	_flashlight_player.volume_db = 0.0
	_flashlight_player.pitch_scale = 1.0
	_flashlight_player.play()
	player_made_sound.emit()

func _emit_flashlight_recharged() -> void:
	flashlight_recharged.emit()
	if flashlight_recharged_sound == null:
		return
	_flashlight_recharged_player.stream = flashlight_recharged_sound
	_flashlight_recharged_player.volume_db = 0.0
	_flashlight_recharged_player.pitch_scale = 1.0
	_flashlight_recharged_player.play()
	player_made_sound.emit()

func _emit_flashlight_activation_denied() -> void:
	flashlight_activation_denied.emit(get_flashlight_charge_ratio())
	if flashlight_denied_sound == null:
		return
	_flashlight_denied_player.stream = flashlight_denied_sound
	_flashlight_denied_player.volume_db = 0.0
	_flashlight_denied_player.pitch_scale = 1.0
	_flashlight_denied_player.play()
	player_made_sound.emit()

func _apply_facing() -> void:
	if pivot:
		pivot.scale = Vector2(abs(_pivot_base_scale.x) * _facing_dir, _pivot_base_scale.y)
	if sprite:
		var x_scale: float = absf(_sprite_base_scale.x) * _sprite_anim_scale.x
		var y_scale: float = _sprite_base_scale.y * _sprite_anim_scale.y
		if not _sprite_under_pivot:
			x_scale *= _facing_dir
		sprite.scale = Vector2(x_scale, y_scale)
	if flashlight and pivot == null:
		flashlight.scale = Vector2(abs(_flashlight_base_scale.x) * _facing_dir, _flashlight_base_scale.y)
		flashlight.offset = _flashlight_base_offset

func _setup_animations() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	_idle_texture = _get_idle_texture()
	_update_walk_loop_bounds()
	if walk_frame_time > 0.0 and sprite.sprite_frames.has_animation(walk_animation):
		sprite.sprite_frames.set_animation_speed(walk_animation, 1.0 / walk_frame_time)

func _get_idle_texture() -> Texture2D:
	if sprite == null or sprite.sprite_frames == null:
		return null
	if idle_animation != StringName() and sprite.sprite_frames.has_animation(idle_animation):
		return sprite.sprite_frames.get_frame_texture(idle_animation, 0)
	if sprite.sprite_frames.has_animation(walk_animation):
		return sprite.sprite_frames.get_frame_texture(walk_animation, 0)
	return null

func _update_walk_loop_bounds() -> void:
	_walk_loop_start = 0
	_walk_loop_end = -1
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(walk_animation):
		return
	var max_index := sprite.sprite_frames.get_frame_count(walk_animation) - 1
	if max_index < 0:
		return
	_walk_loop_start = clampi(walk_loop_start_index - 1, 0, max_index)
	var end_index_req := walk_loop_end_index
	if end_index_req < 0:
		_walk_loop_end = max_index
	else:
		_walk_loop_end = clampi(end_index_req - 1, _walk_loop_start, max_index)

func _calc_texture_scale(texture: Texture2D) -> Vector2:
	if _idle_texture == null or texture == null:
		return Vector2.ONE
	var idle_size := _idle_texture.get_size()
	var tex_size := texture.get_size()
	if idle_size.y <= 0.0 or tex_size.y <= 0.0:
		return Vector2.ONE
	var ratio := idle_size.y / tex_size.y
	return Vector2(ratio, ratio)

func _update_walk_animation(_delta: float, direction: float) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var is_moving := direction != 0.0
	if is_moving:
		if not _is_walking:
			_is_walking = true
			_start_walk_animation()
	else:
		if _is_walking:
			_is_walking = false
			_start_idle_animation()

func _start_walk_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(walk_animation):
		return
	if sprite.animation != walk_animation:
		sprite.play(walk_animation)
	sprite.frame = _walk_loop_start
	sprite.play()
	_enforce_walk_loop_range()

func _start_idle_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if idle_animation != StringName() and sprite.sprite_frames.has_animation(idle_animation):
		if sprite.animation != idle_animation:
			sprite.play(idle_animation)
		return
	sprite.stop()
	sprite.frame = 0
	_update_sprite_scale_for_current_frame()

func _on_sprite_frame_changed() -> void:
	if sprite == null:
		return
	_update_sprite_scale_for_current_frame()
	_enforce_walk_loop_range()

func _update_sprite_scale_for_current_frame() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	_sprite_anim_scale = _calc_texture_scale(texture)
	_apply_facing()

func _enforce_walk_loop_range() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.animation != walk_animation:
		return
	if _walk_loop_end < 0:
		return
	if _adjusting_frame:
		return
	if sprite.frame < _walk_loop_start or sprite.frame > _walk_loop_end:
		_adjusting_frame = true
		sprite.frame = _walk_loop_start
		_adjusting_frame = false

func _on_step_triggered(_frame_index: int, _animation_name: StringName) -> void:
	player_made_sound.emit()

func _resolve_step_audio_component() -> StepAudioComponent:
	if sprite and sprite.has_node("StepAudioComponent"):
		return sprite.get_node("StepAudioComponent") as StepAudioComponent
	if has_node("StepAudioComponent"):
		return get_node("StepAudioComponent") as StepAudioComponent
	return null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_flashlight"):
		_toggle_flashlight()

# ===== Работа с ключами =====
func add_key(key_id: String) -> void:
	if key_id == "": return
	keys[key_id] = true

func has_key(key_id: String) -> bool:
	if key_id == "": return false
	return keys.has(key_id)

func remove_key(key_id: String) -> void:
	if keys.has(key_id): keys.erase(key_id)
	
	
