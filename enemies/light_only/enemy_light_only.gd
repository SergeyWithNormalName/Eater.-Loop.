extends "res://enemies/enemy_flashlight_base.gd"

@export_group("Visual")
## Набор спрайтов для случайного выбора при создании врага.
@export var random_sprites: Array[Texture2D] = []

@export_group("Jump")
## Звуки скачков.
@export var jump_sounds: Array[AudioStream] = []
## Минимальный интервал между скачками.
@export var jump_interval_min: float = 0.6
## Максимальный интервал между скачками.
@export var jump_interval_max: float = 1.2
## Минимальная дистанция скачка.
@export var jump_distance_min: float = 90.0
## Максимальная дистанция скачка.
@export var jump_distance_max: float = 160.0

@export_group("Idle Sounds")
## Дополнительные звуки рядом с противником.
@export var idle_sounds: Array[AudioStream] = []
## Минимальный интервал случайного звука.
@export var idle_sound_interval_min: float = 3.0
## Максимальный интервал случайного звука.
@export var idle_sound_interval_max: float = 6.0

var _jump_timer: float = 0.0
var _idle_sound_timer: float = 0.0
var _jump_player: AudioStreamPlayer2D
var _idle_sound_player: AudioStreamPlayer2D
var _light_active: bool = false

func _ready() -> void:
	super._ready()
	_assign_random_sprite()

	_jump_player = _create_sfx_player()
	_idle_sound_player = _create_sfx_player()

	_reset_jump_timer()
	_reset_idle_sound_timer()

func _assign_random_sprite() -> void:
	if random_sprites.is_empty():
		return
	var sprite_node := _sprite as Sprite2D
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D") as Sprite2D
	if sprite_node == null:
		return
	var chosen_sprite: Texture2D = random_sprites.pick_random() as Texture2D
	if chosen_sprite != null:
		sprite_node.texture = chosen_sprite

func _physics_process(delta: float) -> void:
	if not _is_flashlight_hitting():
		_light_active = false
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not _light_active:
		_light_active = true
		_reset_jump_timer()
		_reset_idle_sound_timer()

	_update_jump(delta)
	_update_idle_sound(delta)

func _update_jump(delta: float) -> void:
	if _player == null or not chase_player:
		return

	_jump_timer -= delta
	if _jump_timer > 0.0:
		return

	var to_player := _player.global_position - global_position
	if to_player.length() <= 0.01:
		_reset_jump_timer()
		return

	var dir := to_player.normalized()
	var distance := _rand_range(jump_distance_min, jump_distance_max)
	var max_distance := to_player.length()
	var applied_distance: float = minf(distance, max_distance)

	_trigger_jump_screen_effect()
	global_position += dir * applied_distance
	velocity = Vector2.ZERO
	_update_facing_from_direction(dir)
	_play_jump_sound()
	_reset_jump_timer()

func _update_idle_sound(delta: float) -> void:
	if idle_sounds.is_empty():
		return

	_idle_sound_timer -= delta
	if _idle_sound_timer <= 0.0:
		_play_idle_sound()
		_reset_idle_sound_timer()

func _play_jump_sound() -> void:
	if jump_sounds.is_empty():
		return
	_jump_player.stream = jump_sounds.pick_random()
	_jump_player.play()

func _trigger_jump_screen_effect() -> void:
	if GameDirector == null:
		return
	GameDirector.trigger_light_only_jump_effect()

func _play_idle_sound() -> void:
	_idle_sound_player.stream = idle_sounds.pick_random()
	_idle_sound_player.play()

func _reset_jump_timer() -> void:
	_jump_timer = _rand_range(jump_interval_min, jump_interval_max)

func _reset_idle_sound_timer() -> void:
	_idle_sound_timer = _rand_range(idle_sound_interval_min, idle_sound_interval_max)

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if not _is_flashlight_hitting():
		return
	super._on_hitbox_area_body_entered(body)

func capture_checkpoint_state() -> Dictionary:
	var state := super.capture_checkpoint_state()
	state["jump_timer"] = _jump_timer
	state["idle_sound_timer"] = _idle_sound_timer
	state["light_active"] = _light_active
	return state

func apply_checkpoint_state(state: Dictionary) -> void:
	super.apply_checkpoint_state(state)
	_jump_timer = float(state.get("jump_timer", _jump_timer))
	_idle_sound_timer = float(state.get("idle_sound_timer", _idle_sound_timer))
	_light_active = bool(state.get("light_active", _light_active))
