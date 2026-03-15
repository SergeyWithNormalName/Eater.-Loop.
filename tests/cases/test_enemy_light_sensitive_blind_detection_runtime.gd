extends "res://tests/test_case.gd"

const PLAYER_SCENE_PATH := "res://player/player.tscn"
const ENEMY_SCENE_PATH := "res://enemies/light_sensitive/enemy_light_sensitive.tscn"
const PICKUP_FLASHLIGHT_SCENE_PATH := "res://objects/interactable/flashlight/pickup_flashlight.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()
	if MusicManager != null and MusicManager.has_method("clear_chase_music_sources"):
		MusicManager.clear_chase_music_sources(0.0)

	var player_scene := assert_loads(PLAYER_SCENE_PATH) as PackedScene
	var enemy_scene := assert_loads(ENEMY_SCENE_PATH) as PackedScene
	var pickup_scene := assert_loads(PICKUP_FLASHLIGHT_SCENE_PATH) as PackedScene
	assert_true(player_scene != null, "Player scene failed to load")
	assert_true(enemy_scene != null, "EnemyLightSensitive scene failed to load")
	assert_true(pickup_scene != null, "Pickup flashlight scene failed to load")
	if player_scene == null or enemy_scene == null or pickup_scene == null:
		return get_failures()

	var root := Node2D.new()
	tree.root.add_child(root)

	var player := player_scene.instantiate()
	var enemy := enemy_scene.instantiate()
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2.RIGHT * 420.0
	root.add_child(player)
	root.add_child(enemy)
	await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame

	assert_true(enemy.get("_player") == player, "Enemy must target the player while not blinded")
	assert_true(bool(enemy.get("_chase_music_started")), "Enemy chase music must start when the player is detected")

	var pickup_flashlight := pickup_scene.instantiate()
	pickup_flashlight.global_position = player.global_position
	root.add_child(pickup_flashlight)
	await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame

	assert_true(bool(enemy.get("_lamp_frozen")), "Enemy must enter blinded lamp-freeze state inside external flashlight beam")
	assert_true(enemy.get("_player") == null, "Enemy must immediately forget the player while blinded by external light")
	assert_true(not bool(enemy.get("_chase_music_started")), "Enemy chase music must stop while external light keeps the enemy harmless")

	enemy.global_position = Vector2.LEFT * 420.0
	await tree.physics_frame
	await tree.physics_frame
	assert_true(not bool(enemy.get("_lamp_frozen")), "Enemy must leave lamp-freeze state after moving out of external light")
	assert_true(enemy.get("_player") == player, "Enemy must reacquire the player after external light blindness ends")
	assert_true(bool(enemy.get("_chase_music_started")), "Enemy chase music must resume after external light blindness ends")

	pickup_flashlight.queue_free()
	await tree.process_frame
	await tree.physics_frame

	CycleState.collect_flashlight_for_cycle()
	player.call("_toggle_flashlight")
	await tree.physics_frame
	assert_true(bool(player.call("is_flashlight_enabled")), "Player flashlight must be enabled for blindness recovery test")

	var lit_position: Variant = await _find_stable_stun_position(tree, player, enemy)
	assert_true(lit_position != null, "Test setup must find a stable player-flashlight stun position")
	if lit_position != null:
		enemy.global_position = lit_position
		enemy.set("_player", player)
		enemy.call("_start_chase_music")
		await tree.physics_frame
		await tree.physics_frame

		assert_true(float(enemy.get("_stun_timer")) > 0.0, "Player flashlight must apply stun while the enemy is inside the beam")
		assert_true(enemy.get("_player") == null, "Enemy must clear the player target while stunned by the player flashlight")
		assert_true(not bool(enemy.get("_chase_music_started")), "Enemy chase music must stay off while the player flashlight is stunning the enemy")

	player.call("_toggle_flashlight")
	await tree.physics_frame

	var reacquired_after_stun := false
	var wait_frames := int(ceil((float(enemy.stun_duration) + 0.5) * 60.0))
	for _i in range(wait_frames):
		await tree.physics_frame
		if enemy.get("_player") == player and bool(enemy.get("_chase_music_started")):
			reacquired_after_stun = true
			break
	assert_true(reacquired_after_stun, "Enemy must reacquire the player only after the player-flashlight stun ends")

	root.queue_free()
	await tree.process_frame
	if MusicManager != null and MusicManager.has_method("clear_chase_music_sources"):
		MusicManager.clear_chase_music_sources(0.0)
	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()
	return get_failures()

func _resolve_lit_offset(player: Node) -> Vector2:
	var candidate_offsets: Array[Vector2] = [
		Vector2.LEFT * 180.0,
		Vector2.RIGHT * 180.0,
		Vector2.LEFT * 240.0,
		Vector2.RIGHT * 240.0,
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
