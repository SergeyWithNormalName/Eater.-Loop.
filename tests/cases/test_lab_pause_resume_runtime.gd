extends "res://tests/test_case.gd"

const LaptopScript := preload("res://objects/interactable/notebook/laptop.gd")
const SqlMinigameScene := preload("res://levels/minigames/labs/sql/sql_minigame.tscn")
const CUSTOM_LAB_MUSIC := preload("res://music/InsideAmbient.wav")
const CUSTOM_LAB_MUSIC_PATH := "res://music/InsideAmbient.wav"
const PAUSE_MUSIC_PATH := "res://music/DrainMusic.wav"
const EXPECTED_MINIGAME_VOLUME_DB := -12.0

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	assert_true(MusicManager != null, "MusicManager autoload is missing")
	assert_true(MinigameController != null, "MinigameController autoload is missing")
	assert_true(PauseManager != null, "PauseManager autoload is missing")
	if tree == null or MusicManager == null or MinigameController == null or PauseManager == null:
		return get_failures()

	await _run_pause_resume_case(tree)
	await _run_pause_spam_case(tree)
	await _cleanup_runtime_state(tree, null, null)
	return get_failures()

func _run_pause_resume_case(tree: SceneTree) -> void:
	var context := await _start_lab_context(tree)
	var laptop: Node = context.get("laptop", null)
	var minigame: Node = context.get("minigame", null)
	if laptop == null or minigame == null:
		return

	var initial_state := MusicManager.get_music_debug_state()
	assert_eq(String(initial_state.get("current_source_kind", "")), MusicManager.SOURCE_KIND_MINIGAME, "Lab must own music before pause opens")
	assert_eq(String(initial_state.get("current_stream_path", "")), CUSTOM_LAB_MUSIC_PATH, "Lab must play the configured custom music before pause opens")
	assert_true(_count_playing_base_players(initial_state) == 1, "Lab must have exactly one active base player before pause opens")

	var time_before_pause := MinigameController.get_time_left()
	await _configure_pause_menu(tree, 0.2, 0.2)
	PauseManager.call("_open_menu")
	await tree.process_frame
	await tree.create_timer(0.25, true).timeout

	var paused_state := MusicManager.get_music_debug_state()
	assert_true(PauseManager.is_pause_menu_open(), "Pause menu must report itself as open during the lab")
	assert_true(bool(paused_state.get("pause_menu_active", false)), "MusicManager must mark pause music as active while pause menu is open")
	assert_eq(String(paused_state.get("pause_transition_state", "")), MusicManager.PAUSE_TRANSITION_OPEN, "Pause transition must settle to open state")
	var paused_player: Dictionary = paused_state.get("pause_player", {})
	assert_true(bool(paused_player.get("playing", false)), "Pause player must be audible while pause menu is open")
	assert_eq(String(paused_player.get("stream_path", "")), PAUSE_MUSIC_PATH, "Pause menu must play the pause track")
	assert_true(_count_playing_base_players(paused_state) == 0, "Lab music must be fully silenced while pause menu is open")

	await tree.create_timer(0.35, true).timeout
	var time_during_pause := MinigameController.get_time_left()
	assert_true(absf(time_during_pause - time_before_pause) < 0.02, "Lab timer must stay frozen while pause menu is open")

	PauseManager.call("_request_resume")
	await tree.process_frame
	await tree.create_timer(0.3, true).timeout

	var resumed_state := MusicManager.get_music_debug_state()
	assert_true(not PauseManager.is_pause_menu_open(), "Pause menu must close after resume")
	assert_true(not bool(resumed_state.get("pause_menu_active", false)), "Pause music must be inactive after resume")
	var resumed_pause_player: Dictionary = resumed_state.get("pause_player", {})
	assert_true(not bool(resumed_pause_player.get("playing", false)), "Pause player must stop after resume")
	assert_eq(String(resumed_state.get("current_source_kind", "")), MusicManager.SOURCE_KIND_MINIGAME, "Lab music must regain ownership after resume")
	assert_eq(String(resumed_state.get("current_stream_path", "")), CUSTOM_LAB_MUSIC_PATH, "Lab music must restore the configured stream after resume")
	assert_true(_count_playing_base_players(resumed_state) == 1, "Exactly one base player must remain active after resume")
	var resumed_player := _get_active_base_player_state(resumed_state)
	assert_true(absf(float(resumed_player.get("volume_db", -80.0)) - EXPECTED_MINIGAME_VOLUME_DB) < 0.35, "Lab music volume must restore to the expected target after resume")

	await tree.create_timer(0.2, true).timeout
	var time_after_resume := MinigameController.get_time_left()
	assert_true(time_after_resume < time_during_pause - 0.05, "Lab timer must continue after resume")

	await _cleanup_runtime_state(tree, laptop, minigame)

func _run_pause_spam_case(tree: SceneTree) -> void:
	var context := await _start_lab_context(tree)
	var laptop: Node = context.get("laptop", null)
	var minigame: Node = context.get("minigame", null)
	if laptop == null or minigame == null:
		return

	await _configure_pause_menu(tree, 0.12, 0.12)
	for _i in range(5):
		PauseManager.call("_open_menu")
		await tree.create_timer(0.08, true).timeout
		PauseManager.call("_request_resume")
		await tree.create_timer(0.08, true).timeout

	await tree.create_timer(0.35, true).timeout
	var final_state := MusicManager.get_music_debug_state()
	assert_true(not PauseManager.is_pause_menu_open(), "Pause menu must end closed after repeated toggles")
	assert_true(not bool(final_state.get("pause_menu_active", false)), "Pause music must not stay active after repeated toggles")
	assert_eq(String(final_state.get("current_source_kind", "")), MusicManager.SOURCE_KIND_MINIGAME, "Lab music must remain the final owner after repeated pause toggles")
	assert_eq(String(final_state.get("current_stream_path", "")), CUSTOM_LAB_MUSIC_PATH, "Lab music stream must survive repeated pause toggles")
	assert_eq(int(final_state.get("stack_depth", -1)), 1, "Pause spam must not duplicate minigame ownership in the music stack")
	assert_true(_count_playing_base_players(final_state) == 1, "Pause spam must settle with exactly one active base player")
	var final_player := _get_active_base_player_state(final_state)
	assert_true(absf(float(final_player.get("volume_db", -80.0)) - EXPECTED_MINIGAME_VOLUME_DB) < 0.35, "Pause spam must not drift lab music volume away from the expected target")
	var pause_player: Dictionary = final_state.get("pause_player", {})
	assert_true(not bool(pause_player.get("playing", false)), "Pause spam must not leave the pause player playing")

	await _cleanup_runtime_state(tree, laptop, minigame)

func _start_lab_context(tree: SceneTree) -> Dictionary:
	await _cleanup_runtime_state(tree, null, null)
	var laptop := LaptopScript.new()
	laptop.minigame_scene = SqlMinigameScene
	laptop.lab_music_stream = CUSTOM_LAB_MUSIC
	tree.root.add_child(laptop)
	await tree.process_frame
	laptop.call("_start_lab_minigame")
	await tree.process_frame
	await tree.process_frame
	var minigame := laptop.get("_current_minigame") as Node
	assert_true(minigame != null, "Laptop must create a timed lab minigame for pause runtime tests")
	if minigame != null:
		assert_true(MinigameController.is_active(minigame), "Timed lab must be active before pause runtime tests")
	return {"laptop": laptop, "minigame": minigame}

func _configure_pause_menu(tree: SceneTree, fade_time: float, resume_fade_time: float) -> void:
	PauseManager.call("_ensure_menu_instance")
	await tree.process_frame
	var pause_menu := PauseManager.get("_pause_menu") as Node
	if pause_menu != null:
		pause_menu.set("menu_music_fade_time", fade_time)
		pause_menu.set("chase_music_resume_fade_time", resume_fade_time)

func _cleanup_runtime_state(tree: SceneTree, laptop: Node, minigame: Node) -> void:
	if PauseManager != null and PauseManager.is_pause_menu_open():
		PauseManager.call("_request_resume")
		await tree.process_frame
	var pause_menu_layer: Node = null
	if PauseManager != null:
		pause_menu_layer = PauseManager.get("_pause_menu_layer") as Node
	if pause_menu_layer != null and is_instance_valid(pause_menu_layer) and pause_menu_layer.is_inside_tree():
		pause_menu_layer.queue_free()
		await tree.process_frame
	if minigame != null and is_instance_valid(minigame):
		if MinigameController != null and MinigameController.is_active(minigame):
			MinigameController.finish_minigame(minigame, false)
		if minigame.is_inside_tree():
			minigame.queue_free()
	if laptop != null and is_instance_valid(laptop) and laptop.is_inside_tree():
		laptop.queue_free()
	await tree.process_frame
	if MusicManager != null:
		if MusicManager.has_method("reset_all_music_state"):
			MusicManager.reset_all_music_state()
		else:
			MusicManager.clear_stack()
			MusicManager.reset_base_music_state()

func _count_playing_base_players(state: Dictionary) -> int:
	var count := 0
	for key in ["base_player_a", "base_player_b"]:
		var player_state: Dictionary = state.get(key, {})
		if bool(player_state.get("playing", false)):
			count += 1
	return count

func _get_active_base_player_state(state: Dictionary) -> Dictionary:
	for key in ["base_player_a", "base_player_b"]:
		var player_state: Dictionary = state.get(key, {})
		if bool(player_state.get("playing", false)):
			return player_state
	return {}
