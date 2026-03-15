extends "res://tests/test_case.gd"

const CREDITS_SCENE_PATH := "res://levels/endings/ending_credits.tscn"
const MAIN_MENU_SCENE_PATH := "res://levels/menu/main_menu.tscn"
const STARTUP_DISCLAIMER_META := "startup_disclaimer_shown_session"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var credits_scene := assert_loads(CREDITS_SCENE_PATH) as PackedScene
	var menu_scene := assert_loads(MAIN_MENU_SCENE_PATH) as PackedScene
	assert_true(credits_scene != null, "Credits scene failed to load")
	assert_true(menu_scene != null, "Main menu scene failed to load")
	if credits_scene == null or menu_scene == null:
		return get_failures()

	if GameState != null and GameState.has_meta(STARTUP_DISCLAIMER_META):
		GameState.remove_meta(STARTUP_DISCLAIMER_META)

	var credits := credits_scene.instantiate()
	tree.root.add_child(credits)
	await tree.process_frame
	await tree.process_frame

	credits.call("_perform_return_transition")
	await tree.process_frame
	await tree.process_frame

	if GameState != null:
		assert_true(bool(GameState.get_meta(STARTUP_DISCLAIMER_META, false)), "Credits return must mark startup disclaimer as already shown for the current session")

	var menu := menu_scene.instantiate()
	tree.root.add_child(menu)
	await tree.process_frame
	await tree.process_frame

	assert_true(not bool(menu.get("_startup_disclaimer_active")), "Main menu must not show embedded startup disclaimer right after credits return")

	menu.queue_free()
	if credits != null and is_instance_valid(credits):
		credits.queue_free()
	await tree.process_frame
	if MusicManager != null and MusicManager.has_method("stop_music"):
		MusicManager.stop_music(0.0)
	if GameState != null and GameState.has_meta(STARTUP_DISCLAIMER_META):
		GameState.remove_meta(STARTUP_DISCLAIMER_META)
	return get_failures()
