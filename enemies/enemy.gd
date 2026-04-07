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
static var _death_screams_cache_ready: bool = false
static var _death_screams_cache: Array[AudioStream] = []
var _death_screams: Array[AudioStream] = []

func _ready() -> void:
	add_to_group(GroupNames.ENEMIES)
	if not is_in_group(GroupNames.CHECKPOINT_STATEFUL):
		add_to_group(GroupNames.CHECKPOINT_STATEFUL)
	if _sprite:
		_sprite_base_scale = _sprite.scale
	_load_death_screams()

func capture_checkpoint_state() -> Dictionary:
	return {
		"has_player_target": _player != null and is_instance_valid(_player),
		"chase_music_started": _chase_music_started,
	}

func apply_checkpoint_state(state: Dictionary) -> void:
	if bool(state.get("has_player_target", false)):
		_player = get_tree().get_first_node_in_group(GroupNames.PLAYER) as Node2D
	else:
		_player = null
	if bool(state.get("chase_music_started", false)):
		_start_chase_music()
	else:
		_stop_chase_music()
	_update_facing_from_velocity()

func _physics_process(_delta: float) -> void:
	if _is_player_busy_with_minigame():
		velocity = Vector2.ZERO
		move_and_slide()
		return
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
	if abs(velocity.x) < 0.1:
		return
	_update_facing_from_direction(velocity)

func _update_facing_from_direction(dir: Vector2) -> void:
	if _sprite == null:
		return
	if abs(dir.x) < 0.01:
		return
	_sprite.scale = Vector2(_sprite_base_scale.x * -sign(dir.x), _sprite_base_scale.y)

func _resolve_visual_node() -> Node2D:
	var animated := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated:
		return animated
	return get_node_or_null("Sprite2D") as Node2D

# --- Сигналы обнаружения (Detection Area) ---

func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group(GroupNames.PLAYER):
		_player = body
		_start_chase_music()

func _on_detection_area_body_exited(body: Node) -> void:
	if body == _player and not keep_chasing_outside_detection:
		_player = null
		_stop_chase_music()

# --- Сигналы касания (Hitbox Area) ---

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if _is_player_busy_with_minigame():
		return
	if body.is_in_group(GroupNames.PLAYER):
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
	if _death_screams_cache_ready:
		_death_screams = _death_screams_cache
		return
	var loaded_streams: Array[AudioStream] = []
	var dir := DirAccess.open(DEATH_SCREAMS_DIR)
	if dir == null:
		_death_screams_cache = loaded_streams
		_death_screams_cache_ready = true
		_death_screams = _death_screams_cache
		return
	var file_names := dir.get_files()
	file_names.sort()
	for file_name in file_names:
		var ext := file_name.get_extension().to_lower()
		if ext != "wav" and ext != "ogg" and ext != "mp3":
			continue
		var stream := load("%s/%s" % [DEATH_SCREAMS_DIR, file_name]) as AudioStream
		if stream != null:
			loaded_streams.append(stream)
	_death_screams_cache = loaded_streams
	_death_screams_cache_ready = true
	_death_screams = _death_screams_cache

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
	if UIMessage:
		UIMessage.play_sfx(stream, attack_sfx_volume_db, pitch)

func _attack_player() -> void:
	if _is_player_busy_with_minigame():
		return
	var is_lethal := kill_on_attack or (CycleState != null and CycleState.phase == CycleState.Phase.DISTORTED)
	if is_lethal:
		_play_attack_sfx(_pick_random_death_scream())
		GameDirector.trigger_death_screen()
		return
	_play_attack_sfx(_pick_random_death_scream())
	GameDirector.trigger_damage_flash()
	GameDirector.reduce_time(time_penalty)
	
	# Удаляем врага, чтобы он не кусал каждый кадр
	call_deferred("queue_free")

func _create_sfx_player() -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.bus = "Sounds"
	add_child(player)
	return player

static func _rand_range(min_val: float, max_val: float) -> float:
	var min_safe := maxf(0.05, min_val)
	var max_safe := maxf(min_safe, max_val)
	return randf_range(min_safe, max_safe)

func _exit_tree() -> void:
	_stop_chase_music()

func _is_player_busy_with_minigame() -> bool:
	if MinigameController == null:
		return false
	return MinigameController.has_active_minigame()
