extends "res://tests/test_case.gd"

const PLAYER_SCENE_PATH := "res://player/player.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()

	var player_scene := assert_loads(PLAYER_SCENE_PATH) as PackedScene
	assert_true(player_scene != null, "Player scene failed to load")
	if player_scene == null:
		return get_failures()

	var root := Node2D.new()
	tree.root.add_child(root)

	var player := player_scene.instantiate()
	root.add_child(player)
	await tree.process_frame

	assert_true(not bool(player.call("has_flashlight_available")), "Player must start without flashlight access")
	player.call("_toggle_flashlight")
	assert_true(not bool(player.call("is_flashlight_enabled")), "Player must not enable flashlight before pickup")

	CycleState.collect_flashlight_for_cycle()
	await tree.physics_frame
	assert_true(bool(player.call("has_flashlight_available")), "Cycle pickup must immediately unlock flashlight for the current cycle")

	player.call("_toggle_flashlight")
	await tree.physics_frame
	assert_true(bool(player.call("is_flashlight_enabled")), "Player flashlight must turn on after pickup")

	CycleState.reset_cycle_state()
	await tree.physics_frame
	assert_true(not bool(player.call("has_flashlight_available")), "Cycle reset must revoke uncommitted flashlight access")
	assert_true(not bool(player.call("is_flashlight_enabled")), "Player flashlight must turn off after cycle reset")

	CycleState.collect_flashlight_for_cycle()
	GameState.next_cycle()
	await tree.physics_frame
	assert_true(GameState.is_flashlight_unlocked(), "Successful cycle completion must promote flashlight unlock to GameState")
	assert_true(bool(player.call("has_flashlight_available")), "Permanent flashlight unlock must survive cycle reset")
	assert_true(not CycleState.flashlight_collected_this_cycle, "Current-cycle flashlight flag must reset after next_cycle")

	root.queue_free()
	await tree.process_frame

	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()

	return get_failures()
