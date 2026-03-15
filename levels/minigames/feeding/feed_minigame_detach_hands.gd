extends "res://levels/minigames/feeding/feed_minigame.gd"

class HandState:
	var node: TextureRect
	var drip_node: ColorRect
	var alpha_mask: Image
	var tear_uv: Vector2
	var base_global_pos: Vector2
	var grab_offset: Vector2 = Vector2.ZERO
	var pull_progress: float = 0.0
	var is_free: bool = false
	var removed: bool = false

const BODY_FACE := preload("res://levels/minigames/feeding/andreys_faces/Amputation/Body.png")
const FIRST_ARM_TEXTURE := preload("res://levels/minigames/feeding/andreys_faces/Amputation/FirstArm.png")
const SECOND_ARM_TEXTURE := preload("res://levels/minigames/feeding/andreys_faces/Amputation/SecondArm.png")
const DRIPS_SHADER := preload("res://shaders/feeding_blood_drips.gdshader")

const SCREAM_STREAMS: Array[AudioStream] = [
	preload("res://player/audio/screams/Scream_1.wav"),
	preload("res://player/audio/screams/Scream_2.wav"),
	preload("res://player/audio/screams/Scream_3.wav"),
	preload("res://player/audio/screams/Scream_4.wav"),
]

@export_range(0.1, 4.0, 0.05) var unlock_progress_speed: float = 1.2
@export_range(0.05, 1.0, 0.01) var initial_follow_factor: float = 0.12
@export_range(0.3, 1.2, 0.01) var max_follow_factor: float = 0.96
@export_range(0.0, 300.0, 1.0) var detach_pull_deadzone: float = 95.0
@export_range(50.0, 1000.0, 1.0) var detach_pull_distance_for_full: float = 420.0
@export_range(0.1, 1.0, 0.01) var scream_repeat_delay: float = 0.25
@export_range(-40.0, 6.0, 0.1) var scream_volume_db: float = -4.0
@export_group("Drip Points")
@export var first_hand_drip_point_path: NodePath = NodePath("FirstHandDripPoint")
@export var second_hand_drip_point_path: NodePath = NodePath("SecondHandDripPoint")
@export_group("Pain Shock")
@export_range(0.0, 1.0, 0.01) var pain_shock_pull_peak: float = 0.55
@export_range(0.0, 1.0, 0.01) var pain_shock_detach_peak: float = 0.85
@export_range(0.1, 6.0, 0.05) var pain_shock_pull_decay_time: float = 1.6
@export_range(0.1, 6.0, 0.05) var pain_shock_detach_decay_time: float = 2.5
@export_range(0.01, 1.0, 0.01) var pain_shock_repeat_cooldown: float = 0.2
@export_group("Creepy Music Stop")
@export_range(0.1, 8.0, 0.1) var creepy_music_stop_duration: float = 4.2
@export_range(0.01, 0.2, 0.01) var creepy_music_target_pitch: float = 0.05

var _hands: Dictionary = {}
var _active_hand_id: StringName = &""
var _hands_intro_completed: bool = false
var _scream_player: AudioStreamPlayer = null
var _scream_cooldown: float = 0.0
var _pain_shock_tween: Tween = null
var _pain_shock_repeat_timer: float = 0.0
var _creepy_music_stop_triggered: bool = false

@onready var pain_overlay: ColorRect = $Control/PainColorRect

func _ready() -> void:
	super._ready()
	_prepare_scream_player()
	_reset_pain_shock_intensity()
	_prepare_hands()

func setup_game(_andrey_texture: Texture2D, count: int, music: AudioStream, win_sound: AudioStream, eat_sound_override: AudioStream = null, bg_override: Texture2D = null, food_scenes: Array[PackedScene] = []) -> void:
	super.setup_game(BODY_FACE, count, music, win_sound, eat_sound_override, bg_override, food_scenes)
	_set_food_mouth_enabled(false)

func _process(delta: float) -> void:
	if _scream_cooldown > 0.0:
		_scream_cooldown = maxf(0.0, _scream_cooldown - delta)
	if _pain_shock_repeat_timer > 0.0:
		_pain_shock_repeat_timer = maxf(0.0, _pain_shock_repeat_timer - delta)
	if _hands_intro_completed:
		return
	if _active_hand_id == &"":
		return
	_update_active_hand_drag(delta)

func _input(event: InputEvent) -> void:
	if _hands_intro_completed:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_try_start_hand_drag(get_viewport().get_mouse_position())
		return
	_stop_active_hand_drag()

func _get_gamepad_focus_nodes() -> Array[Node]:
	if not _hands_intro_completed:
		return []
	return super._get_gamepad_focus_nodes()

func _on_gamepad_confirm(active: Node, context: Dictionary) -> bool:
	if not _hands_intro_completed:
		return false
	return super._on_gamepad_confirm(active, context)

func _prepare_scream_player() -> void:
	_scream_player = AudioStreamPlayer.new()
	_scream_player.bus = "Sounds"
	_scream_player.volume_db = scream_volume_db
	add_child(_scream_player)

func _prepare_hands() -> void:
	_hands.clear()
	_hands_intro_completed = false
	_active_hand_id = &""
	_creepy_music_stop_triggered = false

	var first_arm := _create_hand_layer(
		&"FirstArm",
		FIRST_ARM_TEXTURE,
		Vector2(0.79, 0.34),
		first_hand_drip_point_path
	)
	var second_arm := _create_hand_layer(
		&"SecondArm",
		SECOND_ARM_TEXTURE,
		Vector2(0.90, 0.39),
		second_hand_drip_point_path
	)

	_hands[&"first"] = first_arm
	_hands[&"second"] = second_arm

func _create_hand_layer(node_name: StringName, texture: Texture2D, tear_uv: Vector2, drip_point_path: NodePath) -> HandState:
	var arm := TextureRect.new()
	arm.name = String(node_name)
	arm.texture = texture
	arm.stretch_mode = TextureRect.STRETCH_SCALE
	arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arm.position = Vector2.ZERO
	arm.size = andrey_sprite.size
	arm.z_index = 5
	andrey_sprite.add_child(arm)

	var drip := ColorRect.new()
	drip.name = "%sDrip" % node_name
	drip.color = Color.WHITE
	drip.size = Vector2(130.0, 340.0)
	drip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drip.z_index = 6
	drip.visible = false
	andrey_sprite.add_child(drip)

	var drip_material := ShaderMaterial.new()
	drip_material.shader = DRIPS_SHADER
	drip_material.set_shader_parameter("seed", randf() * 8.0)
	drip.material = drip_material

	var state := HandState.new()
	state.node = arm
	state.drip_node = drip
	state.alpha_mask = texture.get_image()
	state.tear_uv = tear_uv
	state.base_global_pos = arm.global_position

	drip.position = _resolve_drip_position(drip_point_path, arm.size * tear_uv, drip.size)
	return state

func _try_start_hand_drag(pointer_position: Vector2) -> void:
	if _active_hand_id != &"":
		return
	var picked_id := _pick_hand_at_point(pointer_position)
	if picked_id == &"":
		return
	_active_hand_id = picked_id
	var state: HandState = _hands[_active_hand_id] as HandState
	if state == null:
		_active_hand_id = &""
		return
	state.node.z_index = 8
	state.grab_offset = state.node.global_position - pointer_position
	_play_scream(true)
	_trigger_creepy_music_stop_once()
	trigger_pain_shock(pain_shock_pull_peak, pain_shock_pull_decay_time)

func _pick_hand_at_point(point: Vector2) -> StringName:
	var best_id: StringName = &""
	var best_alpha: float = 0.0
	for hand_id in _hands.keys():
		var state: HandState = _hands[hand_id] as HandState
		if state == null or state.removed:
			continue
		if not _point_inside_control(state.node, point):
			continue
		var alpha := _sample_alpha(state, point)
		if alpha <= 0.07:
			continue
		if alpha > best_alpha:
			best_alpha = alpha
			best_id = hand_id
	return best_id

func _point_inside_control(control: Control, point: Vector2) -> bool:
	var local := control.get_global_transform_with_canvas().affine_inverse() * point
	return local.x >= 0.0 and local.y >= 0.0 and local.x <= control.size.x and local.y <= control.size.y

func _sample_alpha(state: HandState, point: Vector2) -> float:
	if state == null or state.alpha_mask == null:
		return 0.0
	var local := state.node.get_global_transform_with_canvas().affine_inverse() * point
	if local.x < 0.0 or local.y < 0.0 or local.x > state.node.size.x or local.y > state.node.size.y:
		return 0.0
	var uv := Vector2(local.x / maxf(1.0, state.node.size.x), local.y / maxf(1.0, state.node.size.y))
	var px := clampi(int(uv.x * float(state.alpha_mask.get_width() - 1)), 0, state.alpha_mask.get_width() - 1)
	var py := clampi(int(uv.y * float(state.alpha_mask.get_height() - 1)), 0, state.alpha_mask.get_height() - 1)
	return state.alpha_mask.get_pixel(px, py).a

func _update_active_hand_drag(delta: float) -> void:
	var state: HandState = _hands.get(_active_hand_id, null) as HandState
	if state == null:
		_active_hand_id = &""
		return
	var pointer: Vector2 = get_viewport().get_mouse_position()

	if state.is_free:
		state.node.global_position = pointer + state.grab_offset
		_play_scream(false)
		return

	var anchor_tear := _get_hand_anchor_tear_point(state)
	var pull_vector := pointer - anchor_tear
	var pull_length := pull_vector.length()
	var follow_factor := lerpf(initial_follow_factor, max_follow_factor, state.pull_progress)
	state.node.global_position = state.base_global_pos + pull_vector * follow_factor

	if pull_length > 3.0:
		var effective_pull := maxf(0.0, pull_length - detach_pull_deadzone)
		if effective_pull > 0.0:
			var required_distance := maxf(1.0, detach_pull_distance_for_full)
			var pull_gain := (effective_pull / required_distance) * unlock_progress_speed * delta
			state.pull_progress = minf(1.0, state.pull_progress + pull_gain)
		_play_scream(false)
		if _pain_shock_repeat_timer <= 0.0:
			trigger_pain_shock(pain_shock_pull_peak, pain_shock_pull_decay_time)
			_pain_shock_repeat_timer = pain_shock_repeat_cooldown

	if state.pull_progress < 1.0:
		return

	state.is_free = true
	state.grab_offset = state.node.global_position - pointer
	_play_scream(true)
	trigger_pain_shock(pain_shock_detach_peak, pain_shock_detach_decay_time)

func _stop_active_hand_drag() -> void:
	if _active_hand_id == &"":
		return
	var hand_id := _active_hand_id
	var state: HandState = _hands.get(hand_id, null) as HandState
	_active_hand_id = &""
	if state == null:
		return
	state.node.z_index = 5
	if state.is_free:
		_finalize_removed_hand(hand_id, state)
		return
	var tween := create_tween()
	tween.tween_property(state.node, "global_position", state.base_global_pos, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _finalize_removed_hand(_hand_id: StringName, state: HandState) -> void:
	if state.removed:
		return
	state.removed = true
	state.node.visible = false
	state.drip_node.visible = true
	trigger_pain_shock(pain_shock_detach_peak, pain_shock_detach_decay_time)
	_check_intro_completion()

func _check_intro_completion() -> void:
	for hand_id in _hands.keys():
		var state: HandState = _hands[hand_id] as HandState
		if state == null or not state.removed:
			return
	_hands_intro_completed = true
	_set_food_mouth_enabled(true)

func _set_food_mouth_enabled(enabled: bool) -> void:
	for child in food_container.get_children():
		if child == null:
			continue
		if not child.has_method("set_target_mouth"):
			continue
		child.set_target_mouth(mouth_area if enabled else null)

func _win() -> void:
	if _is_won:
		return
	_is_won = true
	if MinigameController:
		MinigameController.stop_minigame_music(music_suspend_fade_time)
	if sfx_player and sfx_player.stream:
		sfx_player.play()
	get_tree().create_timer(finish_delay).timeout.connect(_close_game)

func _resolve_drip_position(drip_point_path: NodePath, fallback_local: Vector2, drip_size: Vector2) -> Vector2:
	var point := andrey_sprite.get_node_or_null(drip_point_path) as Node2D
	if point == null:
		return fallback_local - Vector2(drip_size.x * 0.5, 2.0)
	var local_in_face: Vector2 = andrey_sprite.get_global_transform_with_canvas().affine_inverse() * point.global_position
	return local_in_face - Vector2(drip_size.x * 0.5, 2.0)

func _reset_pain_shock_intensity() -> void:
	var material := _get_pain_material()
	if material == null:
		return
	material.set_shader_parameter("intensity", 0.0)

func _get_pain_material() -> ShaderMaterial:
	if pain_overlay == null:
		return null
	return pain_overlay.material as ShaderMaterial

func trigger_pain_shock(peak: float = 1.0, fade_time: float = 2.5) -> void:
	var material := _get_pain_material()
	if material == null:
		return
	if _pain_shock_tween != null and _pain_shock_tween.is_running():
		_pain_shock_tween.kill()
	material.set_shader_parameter("intensity", clampf(peak, 0.0, 1.0))
	_pain_shock_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_pain_shock_tween.tween_property(material, "shader_parameter/intensity", 0.0, maxf(0.01, fade_time))

func _trigger_creepy_music_stop_once() -> void:
	if _creepy_music_stop_triggered:
		return
	_creepy_music_stop_triggered = true
	if MusicManager == null:
		return
	if MusicManager.has_method("stop_minigame_music_with_pitch_drop"):
		MusicManager.stop_minigame_music_with_pitch_drop(creepy_music_stop_duration, creepy_music_target_pitch)

func _get_hand_anchor_tear_point(state: HandState) -> Vector2:
	return state.base_global_pos + state.node.size * state.tear_uv

func _play_scream(force: bool) -> void:
	if _scream_player == null or SCREAM_STREAMS.is_empty():
		return
	if not force:
		if _scream_cooldown > 0.0:
			return
		if _scream_player.playing:
			return
	_scream_player.stream = SCREAM_STREAMS[randi() % SCREAM_STREAMS.size()]
	_scream_player.play()
	_scream_cooldown = scream_repeat_delay
