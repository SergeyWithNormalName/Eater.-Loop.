extends "res://tests/test_case.gd"

const StalkerScript := preload("res://enemies/stalker/enemy_stalker.gd")

class DummyDoor:
	extends Node2D
	var target_marker: NodePath = NodePath("")

class RouteProbeStalker:
	extends "res://enemies/stalker/enemy_stalker.gd"

	var fake_doors: Array[Node] = []
	var fake_exits: Dictionary = {}
	var fake_los: Dictionary = {}
	var door_open_sfx_calls: int = 0

	func _get_doors() -> Array[Node]:
		return fake_doors

	func _get_door_exit_node(door: Node) -> Node2D:
		if door == null:
			return null
		return fake_exits.get(door.get_instance_id(), null) as Node2D

	func _has_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
		return bool(fake_los.get(_los_key(from_pos, to_pos), false))

	func set_los(from_pos: Vector2, to_pos: Vector2, can_see: bool) -> void:
		fake_los[_los_key(from_pos, to_pos)] = can_see

	func _los_key(from_pos: Vector2, to_pos: Vector2) -> String:
		return "%s|%s" % [str(from_pos), str(to_pos)]

	func set_route(route: Array[Node]) -> void:
		_door_route = route.duplicate()

	func get_route_size() -> int:
		return _door_route.size()

	func _play_door_open_sfx() -> void:
		door_open_sfx_calls += 1

func run() -> Array[String]:
	_test_route_search_covers_long_door_chains()
	_test_route_prefers_nearest_visible_door()
	_test_follow_door_route_uses_horizontal_reach()
	_test_self_target_door_is_ignored()
	await _test_door_open_sfx_is_played()
	await _test_stalker_pauses_while_minigame_active()
	return get_failures()

func _test_route_search_covers_long_door_chains() -> void:
	var stalker := RouteProbeStalker.new()
	stalker.max_door_hops = 1

	var start := Vector2(0, 0)
	var target := Vector2(2000, 0)

	var door_a := Node2D.new()
	door_a.position = Vector2(100, 0)
	var door_b := Node2D.new()
	door_b.position = Vector2(300, 0)
	var door_c := Node2D.new()
	door_c.position = Vector2(500, 0)

	var exit_a := Node2D.new()
	exit_a.position = Vector2(220, 0)
	var exit_b := Node2D.new()
	exit_b.position = Vector2(420, 0)
	var exit_c := Node2D.new()
	exit_c.position = Vector2(1500, 0)

	stalker.fake_doors = [door_a, door_b, door_c]
	stalker.fake_exits[door_a.get_instance_id()] = exit_a
	stalker.fake_exits[door_b.get_instance_id()] = exit_b
	stalker.fake_exits[door_c.get_instance_id()] = exit_c

	stalker.set_los(start, target, false)
	stalker.set_los(start, door_a.global_position, true)
	stalker.set_los(exit_a.global_position, target, false)
	stalker.set_los(exit_a.global_position, door_b.global_position, true)
	stalker.set_los(exit_b.global_position, target, false)
	stalker.set_los(exit_b.global_position, door_c.global_position, true)
	stalker.set_los(exit_c.global_position, target, true)

	var route: Array[Node] = stalker.call("_find_door_route", start, target)
	assert_eq(route.size(), 3, "Stalker route search must not stop at legacy max_door_hops")
	if route.size() == 3:
		assert_true(route[0] == door_a and route[1] == door_b and route[2] == door_c, "Stalker must preserve door order in chained route")

	stalker.free()
	door_a.free()
	door_b.free()
	door_c.free()
	exit_a.free()
	exit_b.free()
	exit_c.free()

func _test_route_prefers_nearest_visible_door() -> void:
	var stalker := RouteProbeStalker.new()
	var start := Vector2(0, 0)
	var target := Vector2(1000, 0)

	var near_door := Node2D.new()
	near_door.position = Vector2(120, 0)
	var far_door := Node2D.new()
	far_door.position = Vector2(460, 0)

	var near_exit := Node2D.new()
	near_exit.position = Vector2(820, 0)
	var far_exit := Node2D.new()
	far_exit.position = Vector2(880, 0)

	stalker.fake_doors = [far_door, near_door]
	stalker.fake_exits[near_door.get_instance_id()] = near_exit
	stalker.fake_exits[far_door.get_instance_id()] = far_exit

	stalker.set_los(start, target, false)
	stalker.set_los(start, near_door.global_position, true)
	stalker.set_los(start, far_door.global_position, true)
	stalker.set_los(near_exit.global_position, target, true)
	stalker.set_los(far_exit.global_position, target, true)

	var route: Array[Node] = stalker.call("_find_door_route", start, target)
	assert_eq(route.size(), 1, "Stalker should choose single-door route when both exits have line of sight")
	if route.size() == 1:
		assert_true(route[0] == near_door, "Stalker must prefer the nearest reachable door")

	stalker.free()
	near_door.free()
	far_door.free()
	near_exit.free()
	far_exit.free()

func _test_follow_door_route_uses_horizontal_reach() -> void:
	var stalker := RouteProbeStalker.new()
	var door := DummyDoor.new()
	door.position = Vector2(120, 550)
	door.name = "DoorX"

	var exit_marker := Marker2D.new()
	exit_marker.name = "Exit"
	exit_marker.position = Vector2(340, 550)
	door.add_child(exit_marker)
	door.target_marker = NodePath("Exit")

	stalker.global_position = Vector2(130, -300)
	stalker.fake_exits[door.get_instance_id()] = exit_marker
	stalker.set_route([door])
	stalker.call("_follow_door_route")

	assert_eq(stalker.global_position, exit_marker.global_position, "Stalker must pass through door when horizontally close even with large Y offset")
	assert_eq(stalker.get_route_size(), 0, "Door route should advance after successful teleport")
	assert_eq(stalker.door_open_sfx_calls, 1, "Stalker must play global door-open SFX when using a door")

	stalker.free()
	door.free()

func _test_self_target_door_is_ignored() -> void:
	var stalker := StalkerScript.new()
	var door := DummyDoor.new()
	door.target_marker = NodePath(".")
	var exit_node := stalker.call("_get_door_exit_node", door) as Node2D
	assert_true(exit_node == null, "Door with target_marker='.' must not be used by stalker navigation")
	stalker.free()
	door.free()

func _test_door_open_sfx_is_played() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return

	var stalker := StalkerScript.new()
	tree.root.add_child(stalker)
	await tree.process_frame

	stalker.call("_play_door_open_sfx")
	var door_player := _find_first_door_audio_player(stalker)
	assert_true(door_player != null, "Stalker must have global AudioStreamPlayer for door-open SFX")
	if door_player != null:
		assert_true(door_player.stream == stalker.door_open_sound, "Door-open player must play configured stalker door sound")
		assert_true(door_player.playing, "Door-open SFX must start playing when stalker opens a door")

	stalker.queue_free()
	await tree.process_frame

func _find_first_door_audio_player(stalker: Node) -> AudioStreamPlayer:
	for child in stalker.get_children():
		if child is AudioStreamPlayer:
			return child as AudioStreamPlayer
	return null

func _test_stalker_pauses_while_minigame_active() -> void:
	assert_true(MinigameController != null, "MinigameController autoload is missing")
	if MinigameController == null:
		return

	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return

	if MinigameController.has_method("_force_clear_active_state"):
		MinigameController.call("_force_clear_active_state")

	var stalker := StalkerScript.new()
	var minigame := Node.new()
	minigame.add_to_group("minigame_ui")
	tree.root.add_child(minigame)

	var settings := MinigameSettings.new()
	settings.block_player_movement = true
	MinigameController.start_minigame(minigame, settings)
	await tree.process_frame
	assert_true(bool(stalker.call("_is_player_busy_with_minigame")), "Stalker must detect active minigame and pause pursuit")

	MinigameController.finish_minigame(minigame, false)
	await tree.process_frame
	assert_true(not bool(stalker.call("_is_player_busy_with_minigame")), "Stalker must resume pursuit when minigame ends")

	if is_instance_valid(minigame):
		minigame.queue_free()
		await tree.process_frame
	if MinigameController.has_method("_force_clear_active_state"):
		MinigameController.call("_force_clear_active_state")
	stalker.free()
