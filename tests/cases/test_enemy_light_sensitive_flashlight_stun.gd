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

	var lit_offset := _resolve_lit_offset(player)
	enemy.global_position = player.global_position + lit_offset
	enemy.set("_player", player)
	enemy.chase_player = true
	await tree.physics_frame
	await tree.physics_frame

	assert_true(bool(player.call("is_point_lit", enemy.global_position)), "Enemy must stand inside the player flashlight beam during stun test")
	assert_true(float(enemy.get("_stun_timer")) > 0.0, "Player flashlight must stun the enemy while the beam is hitting")
	assert_true(absf(enemy.velocity.x) < 0.1, "Enemy must stay immobile while player flashlight keeps hitting it")

	for _i in range(20):
		await tree.physics_frame
	assert_true(float(enemy.get("_stun_timer")) > 0.5, "Player flashlight must keep refreshing stun while the beam remains on target")
	assert_true(absf(enemy.velocity.x) < 0.1, "Enemy must remain stunned for the whole duration of continuous flashlight exposure")

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
	var candidate_offsets := [
		Vector2.LEFT * 240.0,
		Vector2.RIGHT * 240.0,
		Vector2.LEFT * 180.0,
		Vector2.RIGHT * 180.0
	]
	for offset in candidate_offsets:
		if bool(player.call("is_point_lit", player.global_position + offset)):
			return offset
	return Vector2.LEFT * 240.0
