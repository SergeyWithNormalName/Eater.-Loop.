extends "res://tests/test_case.gd"

func run() -> Array[String]:
	await _test_level_can_grant_default_flashlight()
	return get_failures()

func _test_level_can_grant_default_flashlight() -> void:
	assert_true(GameState != null, "GameState autoload is missing")
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if GameState == null or tree == null:
		return

	GameState.reset_run()

	var level := load("res://levels/cycles/level.gd").new() as Node2D
	level.set("unlock_flashlight_on_ready", true)
	tree.root.add_child(level)
	await tree.process_frame

	assert_true(GameState.is_flashlight_unlocked(), "Levels marked after corridor distortion must grant flashlight access on load")

	level.queue_free()
	await tree.process_frame
	GameState.reset_run()
