extends "res://tests/test_case.gd"

const LEVEL_SCENE_PATH := "res://levels/cycles/level_12_STU_2.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var level_scene := assert_loads(LEVEL_SCENE_PATH) as PackedScene
	assert_true(level_scene != null, "Level 12 scene failed to load")
	if level_scene == null:
		return get_failures()

	var level := level_scene.instantiate()
	tree.root.add_child(level)
	await tree.process_frame

	var generator := level.get_node_or_null("Generator")
	var fridge := level.get_node_or_null("6thLevel/604/InteractableObjects/Fridge")
	assert_true(generator != null, "Generator node is missing in level_12_STU_2")
	assert_true(fridge != null, "Fridge node is missing in level_12_STU_2")

	if generator != null and fridge != null:
		assert_true(fridge.get("dependency_object") == generator, "Fridge must depend on Generator")
		assert_true(not bool(fridge.call("_is_dependency_satisfied")), "Fridge should be locked before generator interaction")
		generator.call("complete_interaction")
		await tree.process_frame
		assert_true(bool(fridge.call("_is_dependency_satisfied")), "Fridge should unlock after generator interaction")

	assert_true(level.get_node_or_null("Level12MoneySystem") != null, "Level12MoneySystem node is missing")
	assert_true(level.get_node_or_null("StudentMoneyNPC") != null, "StudentMoneyNPC node is missing")
	assert_true(level.get_node_or_null("Blockpost") != null, "Blockpost node is missing")

	var laptop := level.get_node_or_null("Laptop")
	assert_true(laptop != null, "Top-level laptop node is missing")
	if laptop != null:
		assert_true("money_system_path" in laptop, "Laptop must expose money_system_path")

	var note := level.get_node_or_null("Note")
	assert_true(note != null, "Top-level note node is missing")
	if note != null:
		assert_true(note.get("read_audio") != null, "Top-level note should have read_audio assigned")

	level.queue_free()
	await tree.process_frame
	return get_failures()
