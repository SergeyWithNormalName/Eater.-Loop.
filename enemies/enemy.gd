extends CharacterBody2D

## Скорость движения по оси X.
@export var speed: float = 140.0
## Включить преследование игрока.
@export var chase_player: bool = true
## Не прекращать погоню при выходе игрока из зоны видимости.
@export var keep_chasing_outside_detection: bool = false
## Сколько секунд отнимает при касании.
@export var time_penalty: float = 5.0
## Убивает игрока сразу (через экран смерти).
@export var kill_on_attack: bool = false

@export_group("Attack SFX")
## Звук атаки.
@export var attack_sfx: AudioStream = preload("res://music/MyHorrorHit_1.wav")
## Громкость звука атаки (дБ).
@export_range(-80.0, 6.0, 0.1) var attack_sfx_volume_db: float = -2.0
## Минимальный питч звука атаки.
@export_range(0.1, 3.0, 0.01) var attack_sfx_pitch_min: float = 0.95
## Максимальный питч звука атаки.
@export_range(0.1, 3.0, 0.01) var attack_sfx_pitch_max: float = 1.05

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
const DEATH_SCREAMS_DIR := "res://player/audio/screams"
var _death_screams: Array[AudioStream] = []

func _ready() -> void:
	add_to_group("enemies")
	if _sprite:
		_sprite_base_scale = _sprite.scale
	_load_death_screams()

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

func force_stop_chase() -> void:
	_player = null
	velocity = Vector2.ZERO
	_stop_chase_music()

func _set_chase_music_suppressed(suppressed: bool) -> void:
	if MusicManager == null:
		return
	MusicManager.set_chase_music_suppressed(self, suppressed)

func _load_death_screams() -> void:
	_death_screams.clear()
	var dir := DirAccess.open(DEATH_SCREAMS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		var ext := file_name.get_extension().to_lower()
		if ext != "wav" and ext != "ogg" and ext != "mp3":
			continue
		var stream := load("%s/%s" % [DEATH_SCREAMS_DIR, file_name]) as AudioStream
		if stream != null:
			_death_screams.append(stream)

func _pick_random_death_scream() -> AudioStream:
	if _death_screams.is_empty():
		return null
	return _death_screams[randi() % _death_screams.size()]

func _play_attack_sfx(stream_override: AudioStream = null) -> void:
	var stream := stream_override if stream_override != null else attack_sfx
	if stream == null:
		return
	var pitch_min := minf(attack_sfx_pitch_min, attack_sfx_pitch_max)
	var pitch_max := maxf(attack_sfx_pitch_min, attack_sfx_pitch_max)
	var pitch := randf_range(pitch_min, pitch_max)
	if UIMessage and UIMessage.has_method("play_sfx"):
		UIMessage.play_sfx(stream, attack_sfx_volume_db, pitch)
		return
	if get_tree() == null:
		return
	var fallback_player := AudioStreamPlayer.new()
	fallback_player.bus = "Sounds"
	fallback_player.stream = stream
	fallback_player.volume_db = attack_sfx_volume_db
	fallback_player.pitch_scale = pitch
	get_tree().root.add_child(fallback_player)
	fallback_player.finished.connect(func():
		fallback_player.queue_free()
	)
	fallback_player.play()

func _attack_player() -> void:
	var is_lethal := kill_on_attack or GameState.phase == GameState.Phase.DISTORTED
	if is_lethal:
		_play_attack_sfx(_pick_random_death_scream())
		if GameDirector and GameDirector.has_method("trigger_death_screen"):
			GameDirector.trigger_death_screen()
		else:
			if GameState:
				GameState.reset_cycle_state()
			get_tree().call_deferred("reload_current_scene")
		return
	_play_attack_sfx()
	if GameDirector and GameDirector.has_method("reduce_time"):
		GameDirector.reduce_time(time_penalty, true)
	
	# Удаляем врага, чтобы он не кусал каждый кадр
	call_deferred("queue_free")

func _exit_tree() -> void:
	_stop_chase_music()
