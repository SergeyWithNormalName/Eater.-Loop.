extends "res://tests/test_case.gd"

const PICKUP_FLASHLIGHT_SCENE_PATH := "res://objects/interactable/flashlight/pickup_flashlight.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()
	if CycleState != null and CycleState.has_method("reset_cycle_state"):
		CycleState.reset_cycle_state()

	var pickup_scene := assert_loads(PICKUP_FLASHLIGHT_SCENE_PATH) as PackedScene
	assert_true(pickup_scene != null, "Pickup flashlight scene failed to load")
	if pickup_scene == null:
		return get_failures()

	var root := Node2D.new()
	tree.root.add_child(root)

	var pickup_a := pickup_scene.instantiate()
	pickup_a.name = "PickupA"
	root.add_child(pickup_a)

	var pickup_b := pickup_scene.instantiate()
	pickup_b.name = "PickupB"
	pickup_b.position = Vector2(120.0, 0.0)
	root.add_child(pickup_b)
	await tree.process_frame

	assert_true(root.get_node_or_null("PickupA") != null, "First pickup must exist before interaction")
	assert_true(root.get_node_or_null("PickupB") != null, "Second pickup must exist before interaction")

	pickup_a.call("_on_interact")
	await tree.process_frame

	assert_true(root.get_node_or_null("PickupA") == null, "Picked flashlight must disappear from the location")
	assert_true(root.get_node_or_null("PickupB") == null, "All flashlight pickups in the same location must disappear after one is collected")

	root.queue_free()
	await tree.process_frame

	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()
	if CycleState != null and CycleState.has_method("reset_cycle_state"):
		CycleState.reset_cycle_state()

	return get_failures()
