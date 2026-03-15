extends "res://tests/test_case.gd"

func run() -> Array[String]:
	assert_true(MinigameController != null, "MinigameController autoload is missing")
	if MinigameController == null:
		return get_failures()

	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var host := Node.new()
	tree.root.add_child(host)
	await tree.process_frame

	var minigame := Control.new()
	minigame.name = "BackdropVisibilityProbe"
	MinigameController.attach_minigame(minigame, -1, host)
	await tree.process_frame

	var backdrop := _get_backdrop(minigame)
	assert_true(backdrop != null, "Shared mini-game backdrop must be created for plain controls")
	if backdrop != null:
		assert_true(not backdrop.visible, "Backdrop must stay hidden until the transition fade reaches black")

	var previous_transition_enabled := bool(MinigameController.get("minigame_transition_enabled"))
	MinigameController.set("minigame_transition_enabled", false)

	var settings := MinigameSettings.new()
	settings.pause_game = false
	settings.show_mouse_cursor = false
	settings.block_player_movement = false
	MinigameController.start_minigame(minigame, settings)
	await tree.process_frame

	backdrop = _get_backdrop(minigame)
	assert_true(backdrop != null and backdrop.visible, "Backdrop must become visible immediately when transition fades are disabled")

	MinigameController.finish_minigame(minigame, false)
	MinigameController.set("minigame_transition_enabled", previous_transition_enabled)
	minigame.queue_free()
	await tree.process_frame

	host.queue_free()
	await tree.process_frame
	return get_failures()

func _get_backdrop(minigame: Node) -> CanvasLayer:
	var backdrops: Dictionary = MinigameController.get("_minigame_backdrops")
	return backdrops.get(minigame.get_instance_id(), null) as CanvasLayer
