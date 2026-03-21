extends "res://tests/test_case.gd"

const LEVEL_SCENE_PATH := "res://levels/cycles/level_11_STU_1.tscn"
const LAB_MUSIC_PATH := "res://music/MusicForLabs.wav"
const PAUSE_MUSIC_PATH := "res://music/DrainMusic.wav"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	assert_true(MusicManager != null, "MusicManager autoload is missing")
	if tree == null or MusicManager == null:
		return get_failures()

	var level_scene := assert_loads(LEVEL_SCENE_PATH) as PackedScene
	assert_true(level_scene != null, "Level 11 scene failed to load")
	if level_scene == null:
		return get_failures()

	if MusicManager.has_method("reset_all_music_state"):
		MusicManager.reset_all_music_state()
	else:
		MusicManager.clear_stack()
		MusicManager.reset_base_music_state()

	var level := level_scene.instantiate()
	tree.root.add_child(level)
	await tree.process_frame
	await tree.process_frame

	var laptop := level.get_node_or_null("Laptop")
	assert_true(laptop != null, "Top-level laptop node is missing in level_11_STU_1")
	if laptop != null:
		laptop.call("_start_lab_minigame")
		await tree.process_frame
		await tree.process_frame
		var state := MusicManager.get_music_debug_state()
		assert_eq(String(state.get("current_source_kind", "")), MusicManager.SOURCE_KIND_MINIGAME, "Level 11 laptop must start lab music as minigame source")
		assert_eq(String(state.get("current_stream_path", "")), LAB_MUSIC_PATH, "Level 11 laptop must use the dedicated lab track")
		assert_true(String(state.get("current_stream_path", "")) != PAUSE_MUSIC_PATH, "Level 11 laptop must not reuse the pause-menu track as lab music")

	level.queue_free()
	await tree.process_frame
	if MusicManager.has_method("reset_all_music_state"):
		MusicManager.reset_all_music_state()
	else:
		MusicManager.clear_stack()
		MusicManager.reset_base_music_state()
	return get_failures()
