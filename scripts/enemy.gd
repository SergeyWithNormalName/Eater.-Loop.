extends CharacterBody2D

## Скорость движения по оси X.
@export var speed: float = 140.0
## Включить преследование игрока.
@export var chase_player: bool = true
## Не прекращать погоню при выходе игрока из зоны видимости.
@export var keep_chasing_outside_detection: bool = false
## Сколько секунд отнимает при касании.
@export var time_penalty: float = 5.0
## Убивает игрока сразу (перезагрузка сцены).
@export var kill_on_attack: bool = false

@export_group("Chase Music")
## Включить музыку погони.
@export var enable_chase_music: bool = true
## Музыка погони.
@export var chase_music: AudioStream
## Громкость музыки погони (дБ).
@export_range(-80.0, 6.0, 0.1) var chase_music_volume_db: float = -6.0
## Длительность плавного затухания музыки при окончании погони.
@export_range(0.0, 10.0, 0.1) var chase_music_fade_out_time: float = 2.0

var _player: Node2D = null
@onready var _sprite: Node2D = _resolve_visual_node()
var _sprite_base_scale: Vector2 = Vector2.ONE
var _chase_music_started: bool = false

func _ready() -> void:
	if _sprite:
		_sprite_base_scale = _sprite.scale

func _physics_process(_delta: float) -> void:
	if chase_player and _player != null:
		var delta = _player.global_position - global_position
		if abs(delta.x) < 1.0:
			velocity = Vector2.ZERO
		else:
			velocity = Vector2(sign(delta.x) * speed, 0.0)
		move_and_slide()
		_update_facing_from_velocity()
	else:
		velocity = Vector2.ZERO

func _update_facing_from_velocity() -> void:
	if _sprite == null:
		return
	if abs(velocity.x) < 0.1:
		return
	var dir = sign(velocity.x)
	_sprite.scale = Vector2(_sprite_base_scale.x * -dir, _sprite_base_scale.y)

func _resolve_visual_node() -> Node2D:
	var animated := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated:
		return animated
	return get_node_or_null("Sprite2D") as Node2D

# --- Сигналы обнаружения (Detection Area) ---

func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player = body
		_start_chase_music()

func _on_detection_area_body_exited(body: Node) -> void:
	if body == _player and not keep_chasing_outside_detection:
		_player = null
		_stop_chase_music()

# --- Сигналы касания (Hitbox Area) ---

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_attack_player()

func _on_hitbox_area_body_exited(_body: Node2D) -> void:
	pass

func _start_chase_music() -> void:
	if _chase_music_started:
		return
	if not chase_player:
		return
	if not enable_chase_music:
		return
	if chase_music == null:
		return
	if MusicManager == null:
		return
	_chase_music_started = true
	MusicManager.set_chase_music_source(self, true, chase_music, chase_music_volume_db, chase_music_fade_out_time)

func _stop_chase_music() -> void:
	if not _chase_music_started:
		return
	if MusicManager == null:
		return
	_chase_music_started = false
	MusicManager.set_chase_music_source(self, false)

func _set_chase_music_suppressed(suppressed: bool) -> void:
	if MusicManager == null:
		return
	MusicManager.set_chase_music_suppressed(self, suppressed)

func _attack_player() -> void:
	# ИСПРАВЛЕНО: phase вместо current_phase
	if kill_on_attack or GameState.phase == GameState.Phase.DISTORTED:
		UIMessage.show_text("Тебя поглотили.")
		if GameState:
			GameState.reset_cycle_state()
		get_tree().call_deferred("reload_current_scene")
		return
	# ИСПРАВЛЕНО: Теперь функция будет существовать в GameDirector
	GameDirector.reduce_time(time_penalty)
	UIMessage.show_text("Время потеряно! -%.1f с" % time_penalty)
	
	# Удаляем врага, чтобы он не кусал каждый кадр
	call_deferred("queue_free")

func _exit_tree() -> void:
	_stop_chase_music()
