extends "res://tests/test_case.gd"

const LaptopScript := preload("res://objects/interactable/notebook/laptop.gd")
const SqlMinigameScene := preload("res://levels/minigames/labs/sql/sql_minigame.tscn")
const LAB_MUSIC_PATH := "res://music/MusicForLabs.wav"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	assert_true(MusicManager != null, "MusicManager autoload is missing")
	assert_true(MinigameController != null, "MinigameController autoload is missing")
	if tree == null or MusicManager == null or MinigameController == null:
		return get_failures()

	MusicManager.clear_stack()
	MusicManager.reset_base_music_state()

	var laptop := LaptopScript.new()
	laptop.minigame_scene = SqlMinigameScene
	tree.root.add_child(laptop)
	await tree.process_frame

	laptop.call("_start_lab_minigame")
	await tree.process_frame
	await tree.process_frame

	var active_minigame := laptop.get("_current_minigame") as Node
	assert_true(active_minigame != null, "Laptop must create a lab minigame instance")
	if active_minigame != null:
		assert_true(MinigameController.is_active(active_minigame), "Timed lab minigame must be managed by MinigameController")

	var current_stream := MusicManager.get_current_stream()
	assert_true(current_stream != null, "Timed lab minigame must start its dedicated music")
	if current_stream != null:
		assert_eq(String(current_stream.resource_path), LAB_MUSIC_PATH, "Timed lab minigame must play MusicForLabs.wav")

	if active_minigame != null and is_instance_valid(active_minigame):
		if MinigameController.is_active(active_minigame):
			MinigameController.finish_minigame(active_minigame, false)
		if active_minigame.is_inside_tree():
			active_minigame.queue_free()
	if is_instance_valid(laptop) and laptop.is_inside_tree():
		laptop.queue_free()
	await tree.process_frame

	MusicManager.clear_stack()
	MusicManager.reset_base_music_state()
	return get_failures()
