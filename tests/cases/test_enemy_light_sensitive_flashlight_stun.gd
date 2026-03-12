extends "res://tests/test_case.gd"

const PLAYER_SCENE_PATH := "res://player/player.tscn"
const ENEMY_SCENE_PATH := "res://enemies/light_sensitive/enemy_light_sensitive.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()

	var player_scene := assert_loads(PLAYER_SCENE_PATH) as PackedScene
	var enemy_scene := assert_loads(ENEMY_SCENE_PATH) as PackedScene
	assert_true(player_scene != null, "Player scene failed to load")
	assert_true(enemy_scene != null, "EnemyLightSensitive scene failed to load")
	if player_scene == null or enemy_scene == null:
		return get_failures()

	var root := Node2D.new()
	tree.root.add_child(root)

	var player := player_scene.instantiate()
	var enemy := enemy_scene.instantiate()
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(5000.0, 0.0)
	enemy.chase_player = false
	enemy.enable_chase_music = false
	enemy.chase_music = null
	root.add_child(player)
	root.add_child(enemy)
	await tree.process_frame

	CycleState.collect_flashlight_for_cycle()
	player.call("_toggle_flashlight")
	await tree.physics_frame
	assert_true(bool(player.call("is_flashlight_enabled")), "Player flashlight must be enabled for stun test")

	var lit_position: Variant = await _find_stable_stun_position(tree, player, enemy)
	assert_true(lit_position != null, "Test setup must find a stable flashlight-hit position for the enemy")
	if lit_position == null:
		root.queue_free()
		await tree.process_frame
		if GameState != null and GameState.has_method("reset_run"):
			GameState.reset_run()
		return get_failures()
	enemy.global_position = lit_position
	enemy.set("_player", player)
	enemy.chase_player = true
	await tree.physics_frame
	await tree.physics_frame

	assert_true(_any_enemy_probe_lit(player, enemy), "Enemy body must stand inside the player flashlight beam during stun test")
	assert_true(float(enemy.get("_stun_timer")) > 0.0, "Player flashlight must stun the enemy while the beam is hitting")
	assert_true(absf(enemy.velocity.x) < 0.1, "Enemy must stay immobile while player flashlight keeps hitting it")

	for _i in range(20):
		await tree.physics_frame
	assert_true(float(enemy.get("_stun_timer")) > 0.0, "Player flashlight stun must persist while the beam remains on target")
	assert_true(absf(enemy.velocity.x) < 0.1, "Enemy must remain stunned for the whole duration of continuous flashlight exposure")

	var partial_hit_position: Variant = _find_partial_body_hit_position(player, enemy)
	assert_true(partial_hit_position != null, "Test setup must find a position where the beam hits the enemy body before the root point")
	if partial_hit_position != null:
		enemy.global_position = partial_hit_position
		enemy.set("_stun_timer", 0.0)
		enemy.velocity = Vector2.ZERO
		await tree.physics_frame
		await tree.physics_frame
		assert_true(not bool(player.call("is_point_lit", enemy.global_position)), "Enemy root point must stay outside the beam in partial-body hit test")
		assert_true(float(enemy.get("_stun_timer")) > 0.0, "Enemy must react as soon as the flashlight beam touches the body, not only the root point")

	player.call("_toggle_flashlight")
	await tree.physics_frame
	assert_true(not bool(player.call("is_flashlight_enabled")), "Player flashlight must switch off during recovery test")
	assert_true(float(enemy.get("_stun_timer")) > 0.0, "Enemy must keep recovery delay after flashlight stops hitting")

	var resumed_chase := false
	var wait_frames := int(ceil((float(enemy.stun_duration) + 0.4) * 60.0))
	for _i in range(wait_frames):
		await tree.physics_frame
		if absf(enemy.velocity.x) > 0.1:
			resumed_chase = true
			break
	assert_true(resumed_chase, "Enemy must resume chasing only after the flashlight recovery delay expires")

	root.queue_free()
	await tree.process_frame

	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()

	return get_failures()

func _resolve_lit_offset(player: Node) -> Vector2:
	var candidate_offsets: Array[Vector2] = [
		Vector2.LEFT * 180.0,
		Vector2.RIGHT * 180.0,
		Vector2.LEFT * 240.0,
		Vector2.RIGHT * 240.0
	]
	for offset in candidate_offsets:
		if bool(player.call("is_point_lit", player.global_position + offset)):
			return offset
	return Vector2.LEFT * 180.0

func _find_stable_stun_position(tree: SceneTree, player: Node, enemy: Node2D) -> Variant:
	var candidate_offsets: Array[Vector2] = []
	var lit_dir := _resolve_lit_offset(player).normalized()
	var perpendicular := Vector2(-lit_dir.y, lit_dir.x)
	var distances: Array[float] = [220.0, 260.0, 300.0, 340.0]
	var lateral_offsets: Array[float] = [0.0, -60.0, 60.0, -120.0, 120.0]
	for distance in distances:
		for lateral in lateral_offsets:
			candidate_offsets.append(lit_dir * distance + perpendicular * lateral)
	for offset in candidate_offsets:
		enemy.global_position = player.global_position + offset
		enemy.set("_stun_timer", 0.0)
		enemy.velocity = Vector2.ZERO
		var stable := true
		for _i in range(8):
			await tree.physics_frame
			if not is_instance_valid(enemy):
				stable = false
				break
			if float(enemy.get("_stun_timer")) <= 0.0:
				stable = false
				break
		if stable:
			return enemy.global_position
	return null

func _find_partial_body_hit_position(player: Node, enemy: Node2D) -> Variant:
	var base_offset := _resolve_lit_offset(player)
	var candidate_y_offsets: Array[float] = [-420.0, -360.0, -300.0, -240.0, -180.0, 180.0, 240.0, 300.0, 360.0, 420.0]
	for y_offset in candidate_y_offsets:
		var candidate: Vector2 = player.global_position + Vector2(base_offset.x, y_offset)
		enemy.global_position = candidate
		var root_lit := bool(player.call("is_point_lit", enemy.global_position))
		if root_lit:
			continue
		var probe_points: Variant = enemy.call("_get_flashlight_hit_points")
		if not (probe_points is Array):
			continue
		for probe_point in probe_points:
			if probe_point is Vector2 and bool(player.call("is_point_lit", probe_point)):
				return candidate
	return null

func _any_enemy_probe_lit(player: Node, enemy: Node2D) -> bool:
	var probe_points: Variant = enemy.call("_get_flashlight_hit_points")
	if probe_points is Array:
		for probe_point in probe_points:
			if probe_point is Vector2 and bool(player.call("is_point_lit", probe_point)):
				return true
	return false
