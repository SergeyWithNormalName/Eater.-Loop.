extends InteractiveObject

@export_group("Targets")
@export var fridge_path: NodePath
@export var fridge_target_global_position: Vector2 = Vector2(9810, -500)
@export var move_fridge_on_use: bool = true
@export var complete_lab_on_use: bool = true

@export_group("Fade")
@export_range(0.0, 5.0, 0.05) var fade_out_duration: float = 0.4
@export_range(0.0, 5.0, 0.05) var black_screen_hold_duration: float = 0.1
@export_range(0.0, 5.0, 0.05) var fade_in_duration: float = 0.4

@export_group("Visual")
@export var sprite_node: NodePath = NodePath("Sprite2D")
@export var used_sprite: Texture2D

@export_group("Audio")
@export var use_sound: AudioStream
@export_range(-80.0, 6.0, 0.1) var use_sound_volume_db: float = 0.0

var _is_using: bool = false
var _is_used: bool = false
var _audio_player: AudioStreamPlayer2D = null
var _sprite: Sprite2D = null

func _ready() -> void:
	super._ready()
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	
	_audio_player = AudioStreamPlayer2D.new()
	_audio_player.bus = "Sounds"
	_audio_player.max_distance = 2000.0
	_audio_player.volume_db = use_sound_volume_db
	add_child(_audio_player)

func _can_interact() -> bool:
	return not _is_used and not _is_using

func _on_interact() -> void:
	if _is_used or _is_using:
		return

	_is_using = true
	_play_use_sound()
	
	var player := get_interacting_player()
	var player_physics_was_active: bool = false
	if is_instance_valid(player) and player.has_method("is_physics_processing"):
		player_physics_was_active = bool(player.is_physics_processing())
	if is_instance_valid(player) and player.has_method("set_physics_process"):
		player.set_physics_process(false)

	if UIMessage and UIMessage.has_method("fade_out"):
		await UIMessage.fade_out(fade_out_duration)
	else:
		await get_tree().create_timer(max(0.0, fade_out_duration)).timeout

	_apply_winch_effects()
	
	var hold_duration: float = max(0.0, black_screen_hold_duration)
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout

	if UIMessage and UIMessage.has_method("fade_in"):
		await UIMessage.fade_in(fade_in_duration)
	else:
		await get_tree().create_timer(max(0.0, fade_in_duration)).timeout

	if is_instance_valid(player) and player.has_method("set_physics_process"):
		player.set_physics_process(player_physics_was_active)
	
	_is_using = false

func _apply_winch_effects() -> void:
	if _is_used:
		return

	if complete_lab_on_use and GameState and GameState.has_method("mark_lab_completed"):
		GameState.mark_lab_completed()

	if move_fridge_on_use:
		_move_fridge_to_target()
	
	_is_used = true
	_apply_used_visual()
	set_prompts_enabled(false)
	complete_interaction()

func _move_fridge_to_target() -> void:
	if fridge_path.is_empty():
		push_warning("Lebedka: fridge_path is not assigned.")
		return
	
	var fridge := get_node_or_null(fridge_path) as Node2D
	if fridge == null:
		push_warning("Lebedka: fridge_path does not point to Node2D.")
		return
	
	fridge.global_position = fridge_target_global_position

func _apply_used_visual() -> void:
	if _sprite and used_sprite:
		_sprite.texture = used_sprite

func _play_use_sound() -> void:
	if _audio_player == null or use_sound == null:
		return
	_audio_player.stream = use_sound
	_audio_player.volume_db = use_sound_volume_db
	_audio_player.pitch_scale = randf_range(0.97, 1.03)
	_audio_player.play()
