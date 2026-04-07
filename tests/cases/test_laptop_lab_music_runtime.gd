extends "res://tests/test_case.gd"

const LaptopScript := preload("res://objects/interactable/notebook/laptop.gd")
const SqlMinigameScene := preload("res://levels/minigames/labs/sql/sql_minigame.tscn")
const CUSTOM_LAB_MUSIC := preload("res://music/InsideAmbient.wav")
const CUSTOM_LAB_MUSIC_PATH := "res://music/InsideAmbient.wav"

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
	laptop.lab_music_stream = CUSTOM_LAB_MUSIC
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
		assert_eq(String(current_stream.resource_path), CUSTOM_LAB_MUSIC_PATH, "Timed lab minigame must play the music selected on the laptop")
	var active_player := MusicManager.get("_active_player") as AudioStreamPlayer
	assert_true(active_player != null, "MusicManager must expose an active player during timed lab music")
	if active_player != null:
		assert_true(active_player.playing, "Timed lab music must actually be playing, not only assigned as current stream")
		assert_true(active_player.volume_db > -80.0, "Timed lab music player must stay audible")
		active_player.stop()
		await tree.process_frame
		if active_minigame != null and active_minigame.has_method("setup_lab_music"):
			active_minigame.call("setup_lab_music", CUSTOM_LAB_MUSIC)
		await tree.create_timer(0.35, true).timeout
		var recovered_player := MusicManager.get("_active_player") as AudioStreamPlayer
		assert_true(recovered_player != null and recovered_player.playing, "Timed lab music reapply must recover playback if the minigame player fell silent")
		if recovered_player != null:
			assert_eq(String(recovered_player.stream.resource_path), CUSTOM_LAB_MUSIC_PATH, "Timed lab music reapply must keep the laptop-selected stream")

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
