extends "res://tests/test_case.gd"

const LEVEL_SCENE_PATH := "res://levels/cycles/level_12_STU_2.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()
	var original_language := ""
	if SettingsManager != null and SettingsManager.has_method("get_language"):
		original_language = String(SettingsManager.get_language())

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
		var noise_player := fridge.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
		if SettingsManager != null and SettingsManager.has_method("set_language"):
			SettingsManager.set_language("ru")
			await tree.process_frame
			assert_eq(String(fridge.get("locked_message")), "Сначала запусти генератор.", "Fridge must show Russian locked message in Russian locale")
			SettingsManager.set_language("en")
			await tree.process_frame
			assert_eq(String(fridge.get("locked_message")), "Start the generator first.", "Fridge must show English locked message in English locale")
		if noise_player != null:
			assert_true(not noise_player.playing, "Fridge idle noise must stay silent before generator interaction")
		generator.call("complete_interaction")
		await tree.process_frame
		assert_true(bool(fridge.call("_is_dependency_satisfied")), "Fridge should unlock after generator interaction")
		if noise_player != null:
			assert_true(noise_player.playing, "Fridge idle noise must start only after generator interaction")

	assert_true(level.get_node_or_null("Level12MoneySystem") != null, "Level12MoneySystem node is missing")
	assert_true(level.get_node_or_null("StudentMoneyNPC") != null, "StudentMoneyNPC node is missing")

	var laptop := level.get_node_or_null("Laptop")
	assert_true(laptop != null, "Top-level laptop node is missing")
	if laptop != null:
		assert_true("money_system_path" in laptop, "Laptop must expose money_system_path")

	var notes := level.find_children("Note", "", true, false)
	assert_true(notes.size() > 0, "Level 12 should contain at least one Note node")
	for note in notes:
		assert_true("read_audio" in note, "Each level 12 note should expose read_audio property")

	level.queue_free()
	await tree.process_frame
	if original_language != "" and SettingsManager != null and SettingsManager.has_method("set_language"):
		SettingsManager.set_language(original_language)
	return get_failures()
