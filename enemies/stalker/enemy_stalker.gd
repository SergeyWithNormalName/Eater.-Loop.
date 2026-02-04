extends "res://enemies/enemy.gd"

@export_group("Stalker Navigation")
## Distance to trigger door teleport.
@export var door_reach_distance: float = 24.0
## How often to recompute a door route.
@export var route_recalc_interval: float = 0.5
## Maximum number of door hops to search.
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

const WALK_FRAME_PATTERN := "res://enemies/stalker/walking_animation/ezgif-frame-%03d.png"
const WALK_FRAME_COUNT := 26
const IDLE_TEXTURE_PATH := "res://enemies/stalker/sprite.png"

var _route_timer: float = 0.0
var _door_route: Array[Node] = []
var _animated_sprite: AnimatedSprite2D = null

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
	_setup_walk_animation()
	_update_animation()

func _physics_process(delta: float) -> void:
	_ensure_player()
	if _player == null:
		velocity = Vector2.ZERO
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
	if global_position.distance_to(door_pos) <= door_reach_distance:
		var exit_node: Node2D = _get_door_exit_node(door)
		if exit_node != null:
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

	var max_hops: int = maxi(0, max_door_hops)
	var queue: Array[Dictionary] = []
	var initial_route: Array[Node] = []
	queue.append({"pos": start_pos, "route": initial_route})

	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		var route := state["route"] as Array[Node]
		if route.size() >= max_hops:
			continue

		for door in doors:
			if route.has(door):
				continue
			if not _has_line_of_sight(state["pos"], door.global_position):
				continue
			var exit_node: Node2D = _get_door_exit_node(door)
			if exit_node == null:
				continue
			var exit_pos := exit_node.global_position

			var new_route: Array[Node] = route.duplicate()
			new_route.append(door)
			if _has_line_of_sight(exit_pos, target_pos):
				return new_route

			queue.append({"pos": exit_pos, "route": new_route})

	return empty_route

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
	if target_node is Node2D:
		return target_node
	return null

func _setup_walk_animation() -> void:
	if _animated_sprite == null:
		return
	if _animated_sprite.sprite_frames == null:
		_animated_sprite.sprite_frames = SpriteFrames.new()
	var frames := _animated_sprite.sprite_frames
	if not frames.has_animation(walk_animation):
		frames.add_animation(walk_animation)
		for i in range(1, WALK_FRAME_COUNT + 1):
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
