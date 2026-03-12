extends "res://enemies/enemy.gd"

const StalkerMotionAudioComponentScript := preload("res://enemies/stalker/stalker_motion_audio_component.gd")

@export_group("Stalker Navigation")
## Distance to trigger door teleport.
@export var door_reach_distance: float = 24.0
## How often to recompute a door route.
@export var route_recalc_interval: float = 0.5
## Legacy route limit (for compatibility). Stalker now always searches through all doors.
@export var max_door_hops: int = 6
## Collision mask for navigation rays (0 = use current collision_mask).
@export var nav_collision_mask: int = 0

@export_group("Animation")
## Имя анимации ходьбы.
@export var walk_animation: StringName = &"walk"
## Имя анимации покоя.
@export var idle_animation: StringName = &"idle"
## Длительность кадра ходьбы в секундах.
@export var walk_frame_time: float = 0.08

@export_group("Door Audio")
## Звук открытия двери stalker (слышен по всей локации).
@export var door_open_sound: AudioStream = preload("res://enemies/stalker/StalkerOpenDoor.wav")
## Громкость открытия двери в дБ.
@export var door_open_volume_db: float = -5.0
## Минимальный питч открытия двери.
@export var door_open_pitch_min: float = 0.98
## Максимальный питч открытия двери.
@export var door_open_pitch_max: float = 1.02
## Шина для звука открытия двери.
@export var door_open_audio_bus: StringName = &"Sounds"

@export_group("Motion Audio")
## Путь к уникальному компоненту аудио шагов/скрипа stalker.
@export var motion_audio_component_path: NodePath = NodePath("StalkerMotionAudio")

const WALK_FRAME_PATTERN := "res://enemies/stalker/walking_animation/ezgif-frame-%03d.png"
const WALK_FRAME_START := 8
const WALK_FRAME_END := 29
const IDLE_TEXTURE_PATH := "res://enemies/stalker/sprite.png"

var _route_timer: float = 0.0
var _door_route: Array[Node] = []
var _animated_sprite: AnimatedSprite2D = null
var _door_open_player: AudioStreamPlayer = null
var _motion_audio: StalkerMotionAudioComponent = null

func _ready() -> void:
	super._ready()
	enable_chase_music = false
	keep_chasing_outside_detection = true
	chase_player = true
	_animated_sprite = _sprite as AnimatedSprite2D
	if _animated_sprite == null:
		_animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if _animated_sprite != null:
			_sprite = _animated_sprite
	_setup_audio()
	_setup_walk_animation()
	_update_animation()

func _physics_process(delta: float) -> void:
	_ensure_player()
	if _player == null:
		velocity = Vector2.ZERO
		_update_animation()
		return
	if _is_player_busy_with_minigame():
		velocity = Vector2.ZERO
		_door_route.clear()
		_route_timer = 0.0
		_update_animation()
		return

	_route_timer -= delta
	var has_direct := _has_line_of_sight(global_position, _player.global_position)
	if has_direct:
		_door_route.clear()

	if _route_timer <= 0.0:
		_route_timer = max(0.05, route_recalc_interval)
		if not has_direct:
			_door_route = _find_door_route(global_position, _player.global_position)
		else:
			_door_route.clear()

	if _door_route.size() > 0:
		_follow_door_route()
	else:
		_move_towards(_player.global_position)
	_update_animation()

func _ensure_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _follow_door_route() -> void:
	if _door_route.is_empty():
		return
	var door := _door_route[0] as Node2D
	if door == null or not is_instance_valid(door):
		_door_route.pop_front()
		return

	var door_pos := door.global_position
	if _is_within_door_reach(door_pos):
		var exit_node: Node2D = _get_door_exit_node(door)
		if exit_node != null:
			_play_door_open_sfx()
			global_position = exit_node.global_position
		_door_route.pop_front()
		_route_timer = 0.0
		return

	_move_towards(door_pos)

func _move_towards(target_pos: Vector2) -> void:
	var delta_pos := target_pos - global_position
	if abs(delta_pos.x) < 1.0:
		velocity = Vector2.ZERO
	else:
		velocity = Vector2(sign(delta_pos.x) * speed, 0.0)
	move_and_slide()
	_update_facing_from_velocity()

func _has_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = nav_collision_mask if nav_collision_mask != 0 else collision_mask
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.get("collider") == _player

func _find_door_route(start_pos: Vector2, target_pos: Vector2) -> Array[Node]:
	var empty_route: Array[Node] = []
	if _has_line_of_sight(start_pos, target_pos):
		return empty_route

	var doors := _get_doors()
	if doors.is_empty():
		return empty_route

	# Route length can never exceed number of unique doors, so this guarantees
	# full search regardless of legacy max_door_hops values.
	var max_hops: int = doors.size()
	if max_door_hops > max_hops:
		max_hops = max_door_hops
	var queue: Array[Dictionary] = []
	var best_depth_for_exit: Dictionary = {}
	var initial_route: Array[Node] = []
	queue.append({"pos": start_pos, "route": initial_route})

	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		var route := state["route"] as Array[Node]
		var state_pos: Vector2 = state["pos"]
		var doors_for_state := _sort_doors_for_state(doors, state_pos, target_pos)

		for door in doors_for_state:
			if route.has(door):
				continue
			if not _can_approach_door(state_pos, door):
				continue
			var exit_node: Node2D = _get_door_exit_node(door)
			if exit_node == null:
				continue
			var exit_pos := exit_node.global_position

			var new_route: Array[Node] = route.duplicate()
			new_route.append(door)
			if _has_line_of_sight(exit_pos, target_pos):
				return new_route
			if new_route.size() >= max_hops:
				continue

			var exit_id := exit_node.get_instance_id()
			var best_known_depth := int(best_depth_for_exit.get(exit_id, -1))
			if best_known_depth >= 0 and best_known_depth <= new_route.size():
				continue
			best_depth_for_exit[exit_id] = new_route.size()

			queue.append({"pos": exit_pos, "route": new_route})

	return empty_route

func _can_approach_door(from_pos: Vector2, door: Node2D) -> bool:
	if door == null:
		return false
	var door_pos := door.global_position
	if _has_line_of_sight(from_pos, door_pos):
		return true
	var horizontal_approach := Vector2(door_pos.x, from_pos.y)
	return _has_line_of_sight(from_pos, horizontal_approach)

func _sort_doors_for_state(doors: Array[Node], from_pos: Vector2, target_pos: Vector2) -> Array[Node]:
	var sorted_doors: Array[Node] = doors.duplicate()
	sorted_doors.sort_custom(func(a: Node, b: Node) -> bool:
		var a_door := a as Node2D
		var b_door := b as Node2D
		if a_door == null and b_door == null:
			return false
		if a_door == null:
			return false
		if b_door == null:
			return true
		var dist_a := from_pos.distance_squared_to(a_door.global_position)
		var dist_b := from_pos.distance_squared_to(b_door.global_position)
		if is_equal_approx(dist_a, dist_b):
			var target_dist_a := target_pos.distance_squared_to(a_door.global_position)
			var target_dist_b := target_pos.distance_squared_to(b_door.global_position)
			return target_dist_a < target_dist_b
		return dist_a < dist_b
	)
	return sorted_doors

func _get_doors() -> Array[Node]:
	var nodes := get_tree().get_nodes_in_group("doors")
	var doors: Array[Node] = []
	for node in nodes:
		if node is Node2D:
			doors.append(node)
	return doors

func _get_door_exit_node(door: Node) -> Node2D:
	if door == null:
		return null
	var target_path = door.get("target_marker")
	if target_path == null or typeof(target_path) != TYPE_NODE_PATH:
		return null
	if target_path == NodePath(""):
		return null
	var target_node := door.get_node_or_null(target_path)
	if target_node == null:
		return null
	# Self-references (NodePath(".")) are invalid exits for teleport navigation.
	if target_node == door:
		return null
	if target_node is Node2D:
		return target_node
	return null

func _is_within_door_reach(door_pos: Vector2) -> bool:
	return absf(global_position.x - door_pos.x) <= door_reach_distance

func _is_player_busy_with_minigame() -> bool:
	return super._is_player_busy_with_minigame()

func _setup_audio() -> void:
	_ensure_door_open_player()
	_motion_audio = _resolve_motion_audio_component()

func _ensure_door_open_player() -> AudioStreamPlayer:
	if _door_open_player != null and is_instance_valid(_door_open_player):
		return _door_open_player
	_door_open_player = AudioStreamPlayer.new()
	_door_open_player.bus = door_open_audio_bus
	_door_open_player.max_polyphony = 4
	add_child(_door_open_player)
	return _door_open_player

func _resolve_motion_audio_component() -> StalkerMotionAudioComponent:
	if motion_audio_component_path != NodePath():
		var by_path := get_node_or_null(motion_audio_component_path) as StalkerMotionAudioComponentScript
		if by_path != null:
			return by_path
	for child in get_children():
		var component := child as StalkerMotionAudioComponentScript
		if component != null:
			return component
	return null

func _play_door_open_sfx() -> void:
	if door_open_sound == null:
		return
	var player := _ensure_door_open_player()
	if player == null:
		return
	player.bus = door_open_audio_bus
	player.stream = door_open_sound
	player.volume_db = door_open_volume_db
	player.pitch_scale = randf_range(minf(door_open_pitch_min, door_open_pitch_max), maxf(door_open_pitch_min, door_open_pitch_max))
	player.play()

func _setup_walk_animation() -> void:
	if _animated_sprite == null:
		return
	if _animated_sprite.sprite_frames == null:
		_animated_sprite.sprite_frames = SpriteFrames.new()
	var frames := _animated_sprite.sprite_frames
	if not frames.has_animation(walk_animation):
		frames.add_animation(walk_animation)
		for i in range(WALK_FRAME_START, WALK_FRAME_END + 1):
			var texture := load(WALK_FRAME_PATTERN % i) as Texture2D
			if texture != null:
				frames.add_frame(walk_animation, texture)
	if frames.has_animation(walk_animation):
		if walk_frame_time > 0.0:
			frames.set_animation_speed(walk_animation, 1.0 / walk_frame_time)
		frames.set_animation_loop(walk_animation, true)
	if idle_animation != StringName() and not frames.has_animation(idle_animation):
		var idle_texture := load(IDLE_TEXTURE_PATH) as Texture2D
		if idle_texture != null:
			frames.add_animation(idle_animation)
			frames.add_frame(idle_animation, idle_texture)
			frames.set_animation_loop(idle_animation, true)

func _update_animation() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	var moving: bool = absf(velocity.x) > 0.1
	var target_anim := walk_animation if moving else idle_animation
	if target_anim != StringName() and _animated_sprite.sprite_frames.has_animation(target_anim):
		if _animated_sprite.animation != target_anim or not _animated_sprite.is_playing():
			_animated_sprite.play(target_anim)
	elif moving and _animated_sprite.sprite_frames.has_animation(walk_animation):
		_animated_sprite.play(walk_animation)
	else:
		_animated_sprite.stop()
		_animated_sprite.frame = 0

func capture_checkpoint_state() -> Dictionary:
	var state := super.capture_checkpoint_state()
	state["route_timer"] = _route_timer
	if _animated_sprite != null:
		state["animation"] = String(_animated_sprite.animation)
		state["frame"] = _animated_sprite.frame
		state["animation_playing"] = _animated_sprite.is_playing()
	return state

func apply_checkpoint_state(state: Dictionary) -> void:
	super.apply_checkpoint_state(state)
	_route_timer = float(state.get("route_timer", _route_timer))
	_door_route.clear()
	if _animated_sprite != null:
		var animation_name := StringName(state.get("animation", String(_animated_sprite.animation)))
		if animation_name != StringName() and _animated_sprite.sprite_frames != null and _animated_sprite.sprite_frames.has_animation(animation_name):
			_animated_sprite.play(animation_name)
			_animated_sprite.frame = int(state.get("frame", _animated_sprite.frame))
			if not bool(state.get("animation_playing", true)):
				_animated_sprite.stop()
