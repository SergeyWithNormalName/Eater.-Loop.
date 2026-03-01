extends "res://tests/test_case.gd"

const LAPTOP_SCENE_PATH := "res://objects/interactable/notebook/laptop_STU.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	if GameState and GameState.has_method("reset_run"):
		GameState.reset_run()

	var laptop_scene := assert_loads(LAPTOP_SCENE_PATH) as PackedScene
	assert_true(laptop_scene != null, "Laptop scene failed to load")
	if laptop_scene == null:
		return get_failures()

	var root := Node.new()
	tree.root.add_child(root)

	var laptop_a := laptop_scene.instantiate()
	var laptop_b := laptop_scene.instantiate()
	laptop_a.set("lab_completion_id", "test_lab_a")
	laptop_b.set("lab_completion_id", "test_lab_b")
	root.add_child(laptop_a)
	root.add_child(laptop_b)
	await tree.process_frame

	assert_true(not bool(laptop_a.call("_is_lab_completed")), "Laptop A must start incomplete")
	assert_true(not bool(laptop_b.call("_is_lab_completed")), "Laptop B must start incomplete")

	GameState.mark_lab_completed("test_lab_a")
	assert_true(bool(laptop_a.call("_is_lab_completed")), "Laptop A must be completed after its own lab ID")
	assert_true(not bool(laptop_b.call("_is_lab_completed")), "Laptop B must stay available after Laptop A completion")
	assert_true(GameState.is_lab_completed("test_lab_a"), "GameState must remember completed lab ID")
	assert_true(not GameState.is_lab_completed("test_lab_b"), "GameState must not mark unrelated lab ID")
	assert_true(GameState.lab_done, "Global lab_done should still be set for backwards compatibility")

	root.queue_free()
	await tree.process_frame

	if GameState and GameState.has_method("reset_run"):
		GameState.reset_run()

	return get_failures()
