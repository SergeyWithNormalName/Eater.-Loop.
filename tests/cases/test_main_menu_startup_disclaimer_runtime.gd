extends "res://tests/test_case.gd"

const MAIN_MENU_SCENE_PATH := "res://levels/menu/main_menu.tscn"
const STARTUP_DISCLAIMER_META := "startup_disclaimer_shown_session"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var menu_scene := assert_loads(MAIN_MENU_SCENE_PATH) as PackedScene
	assert_true(menu_scene != null, "Main menu scene failed to load")
	if menu_scene == null:
		return get_failures()

	if GameState != null and GameState.has_meta(STARTUP_DISCLAIMER_META):
		GameState.remove_meta(STARTUP_DISCLAIMER_META)
	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()

	var first_menu := menu_scene.instantiate()
	tree.root.add_child(first_menu)
	await tree.process_frame
	await tree.process_frame

	assert_true(bool(first_menu.get("_startup_disclaimer_active")), "Startup disclaimer must appear on the first main-menu open in a session")
	if GameState != null:
		assert_true(bool(GameState.get_meta(STARTUP_DISCLAIMER_META, false)), "Startup disclaimer must mark the current session after the first show")

	first_menu.queue_free()
	await tree.process_frame

	var second_menu := menu_scene.instantiate()
	tree.root.add_child(second_menu)
	await tree.process_frame
	await tree.process_frame

	assert_true(not bool(second_menu.get("_startup_disclaimer_active")), "Startup disclaimer must stay hidden when returning to the main menu in the same session")
	var disclaimer_root := second_menu.get_node_or_null("StartupDisclaimer") as Control
	if disclaimer_root != null:
		assert_true(not disclaimer_root.visible, "Startup disclaimer root must remain hidden on subsequent menu opens in the same session")

	second_menu.queue_free()
	await tree.process_frame
	if MusicManager != null and MusicManager.has_method("stop_music"):
		MusicManager.stop_music(0.0)
	if GameState != null and GameState.has_meta(STARTUP_DISCLAIMER_META):
		GameState.remove_meta(STARTUP_DISCLAIMER_META)
	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()
	return get_failures()
