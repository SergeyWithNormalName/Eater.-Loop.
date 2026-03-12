extends "res://tests/test_case.gd"

const PROJECTOR_SCENE_PATH := "res://objects/interactable/projector/projector.tscn"
const PICKUP_FLASHLIGHT_SCENE_PATH := "res://objects/interactable/flashlight/pickup_flashlight.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()

	var projector_scene := assert_loads(PROJECTOR_SCENE_PATH) as PackedScene
	var pickup_scene := assert_loads(PICKUP_FLASHLIGHT_SCENE_PATH) as PackedScene
	assert_true(projector_scene != null, "Projector scene failed to load")
	assert_true(pickup_scene != null, "Pickup flashlight scene failed to load")
	if projector_scene == null or pickup_scene == null:
		return get_failures()

	var root := Node2D.new()
	tree.root.add_child(root)

	var projector := projector_scene.instantiate()
	projector.position = Vector2.ZERO
	root.add_child(projector)

	var pickup_flashlight := pickup_scene.instantiate()
	pickup_flashlight.position = Vector2(400.0, 0.0)
	root.add_child(pickup_flashlight)
	await tree.process_frame

	projector.call("turn_on")
	assert_true(projector.is_in_group("reactive_light_source"), "Projector must register as reactive_light_source")
	assert_true(pickup_flashlight.is_in_group("reactive_light_source"), "Pickup flashlight must register as reactive_light_source")

	assert_true(bool(projector.call("is_point_lit", projector.global_position + Vector2.RIGHT * 320.0)), "Projector must light targets in front of it")
	assert_true(not bool(projector.call("is_point_lit", projector.global_position + Vector2.LEFT * 320.0)), "Projector must not light targets behind it")

	assert_true(bool(pickup_flashlight.call("is_point_lit", pickup_flashlight.global_position + Vector2.LEFT * 240.0)), "Pickup flashlight must light targets in front of its beam")
	assert_true(not bool(pickup_flashlight.call("is_point_lit", pickup_flashlight.global_position + Vector2.RIGHT * 240.0)), "Pickup flashlight must not light targets behind it")

	root.queue_free()
	await tree.process_frame

	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()

	return get_failures()
