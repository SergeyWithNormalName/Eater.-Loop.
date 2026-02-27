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
const PAIN_SHOCK_SHADER := preload("res://shaders/pain_shock_distortion.gdshader")

const SCREAM_STREAMS: Array[AudioStream] = [
	preload("res://player/audio/screams/Scream_1.wav"),
	preload("res://player/audio/screams/Scream_2.wav"),
	preload("res://player/audio/screams/Scream_3.wav"),
	preload("res://player/audio/screams/Scream_4.wav"),
]

@export_range(0.1, 4.0, 0.05) var unlock_progress_speed: float = 1.2
@export_range(0.05, 1.0, 0.01) var initial_follow_factor: float = 0.12
@export_range(0.3, 1.2, 0.01) var max_follow_factor: float = 0.96
@export_range(0.1, 1.0, 0.01) var scream_repeat_delay: float = 0.25
@export_range(-40.0, 6.0, 0.1) var scream_volume_db: float = -4.0
@export_group("Drip Points")
@export var first_hand_drip_point_path: NodePath = NodePath("FirstHandDripPoint")
@export var second_hand_drip_point_path: NodePath = NodePath("SecondHandDripPoint")
@export_group("Pain Shock")
@export_range(0.5, 20.0, 0.1) var pain_shock_response_speed: float = 11.0
@export_range(0.0, 1.0, 0.01) var pain_shock_free_intensity: float = 0.45
@export_range(0.0, 1.0, 0.01) var pain_shock_pull_base_intensity: float = 0.55
@export_range(0.0, 1.0, 0.01) var pain_shock_pull_bonus_intensity: float = 0.3

var _hands: Dictionary = {}
var _active_hand_id: StringName = &""
var _hands_intro_completed: bool = false
var _scream_player: AudioStreamPlayer = null
var _scream_cooldown: float = 0.0
var _pain_shock_rect: ColorRect = null
var _pain_shock_material: ShaderMaterial = null
var _pain_shock_intensity: float = 0.0

func _ready() -> void:
	super._ready()
	_prepare_scream_player()
	_prepare_pain_shock_overlay()
	_prepare_hands()

func setup_game(_andrey_texture: Texture2D, count: int, music: AudioStream, win_sound: AudioStream, eat_sound_override: AudioStream = null, bg_override: Texture2D = null, food_scenes: Array[PackedScene] = []) -> void:
	super.setup_game(BODY_FACE, count, music, win_sound, eat_sound_override, bg_override, food_scenes)
	_set_food_mouth_enabled(false)

func _process(delta: float) -> void:
	if _scream_cooldown > 0.0:
		_scream_cooldown = maxf(0.0, _scream_cooldown - delta)
	_update_pain_shock(delta)
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

func _prepare_pain_shock_overlay() -> void:
	if _pain_shock_rect != null:
		return
	_pain_shock_rect = ColorRect.new()
	_pain_shock_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pain_shock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pain_shock_rect.color = Color.WHITE
	_pain_shock_rect.z_index = 150
	_pain_shock_rect.visible = false

	_pain_shock_material = ShaderMaterial.new()
	_pain_shock_material.shader = PAIN_SHOCK_SHADER
	_pain_shock_material.set_shader_parameter("intensity", 0.0)
	_pain_shock_rect.material = _pain_shock_material

	var parent_control := get_node_or_null("Control") as Control
	if parent_control != null:
		parent_control.add_child(_pain_shock_rect)
	else:
		add_child(_pain_shock_rect)

func _prepare_hands() -> void:
	_hands.clear()
	_hands_intro_completed = false
	_active_hand_id = &""

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
		state.pull_progress = minf(1.0, state.pull_progress + (pull_length / 220.0) * unlock_progress_speed * delta)
		_play_scream(false)

	if state.pull_progress < 1.0:
		return

	state.is_free = true
	state.grab_offset = state.node.global_position - pointer
	_play_scream(true)

func _stop_active_hand_drag() -> void:
	if _active_hand_id == &"":
		return
	var state: HandState = _hands.get(_active_hand_id, null) as HandState
	_active_hand_id = &""
	if state == null:
		return
	state.node.z_index = 5
	if state.is_free:
		_finalize_removed_hand(state)
		return
	var tween := create_tween()
	tween.tween_property(state.node, "global_position", state.base_global_pos, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _finalize_removed_hand(state: HandState) -> void:
	if state.removed:
		return
	state.removed = true
	state.node.visible = false
	state.drip_node.visible = true
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

func _resolve_drip_position(drip_point_path: NodePath, fallback_local: Vector2, drip_size: Vector2) -> Vector2:
	var point := andrey_sprite.get_node_or_null(drip_point_path) as Node2D
	if point == null:
		return fallback_local - Vector2(drip_size.x * 0.5, 2.0)
	var local_in_face: Vector2 = andrey_sprite.get_global_transform_with_canvas().affine_inverse() * point.global_position
	return local_in_face - Vector2(drip_size.x * 0.5, 2.0)

func _update_pain_shock(delta: float) -> void:
	if _pain_shock_rect == null or _pain_shock_material == null:
		return
	var target_intensity := _get_pain_shock_target_intensity()
	var weight := clampf(delta * pain_shock_response_speed, 0.0, 1.0)
	_pain_shock_intensity = lerpf(_pain_shock_intensity, target_intensity, weight)
	if _pain_shock_intensity < 0.002 and target_intensity <= 0.001:
		_pain_shock_intensity = 0.0
	_pain_shock_rect.visible = _pain_shock_intensity > 0.0
	_pain_shock_material.set_shader_parameter("intensity", _pain_shock_intensity)

func _get_pain_shock_target_intensity() -> float:
	if _hands_intro_completed:
		return 0.0
	if _active_hand_id == &"":
		return 0.0
	var state: HandState = _hands.get(_active_hand_id, null) as HandState
	if state == null or state.removed:
		return 0.0
	if state.is_free:
		return pain_shock_free_intensity
	return clampf(
		pain_shock_pull_base_intensity + state.pull_progress * pain_shock_pull_bonus_intensity,
		0.0,
		1.0
	)

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
