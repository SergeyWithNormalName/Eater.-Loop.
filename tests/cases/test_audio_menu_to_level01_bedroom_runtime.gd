extends "res://tests/test_case.gd"

const MAIN_MENU_SCENE_PATH := "res://levels/menu/main_menu.tscn"
const LEVEL01_SCENE_PATH := "res://levels/cycles/level_01_start.tscn"
const BEDROOM_TRIGGER_PATH := "TriggerBedroomSilent"
const START_DIFFICULTY_SIMPLIFIED := 0
const MENU_TRANSITION_TIMEOUT_SEC := 12.0

func run() -> Array[String]:
	var tree: SceneTree = _scene_tree()
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	await _open_main_menu_scene(tree)
	var menu: Node = tree.current_scene
	assert_true(menu != null, "Main menu scene is not available")
	if menu == null:
		return get_failures()

	_prepare_new_game_state(menu)
	menu.call("_start_new_game", START_DIFFICULTY_SIMPLIFIED)
	var switched := await _await_scene_path_or_timeout(tree, LEVEL01_SCENE_PATH, MENU_TRANSITION_TIMEOUT_SEC)
	assert_true(switched, "Menu -> level transition timed out")
	if not switched:
		return get_failures()

	await tree.process_frame
	await tree.process_frame

	var scene: Node = tree.current_scene
	assert_true(scene != null, "Current scene is null after starting a new game")
	if scene == null:
		return get_failures()
	assert_eq(scene.scene_file_path, LEVEL01_SCENE_PATH, "Expected level_01_start scene after new game")
	var settled := await _await_bedroom_state(tree, scene, 3.0)
	assert_true(settled, "Bedroom start state did not settle in time")

	var trigger: Area2D = scene.get_node_or_null(BEDROOM_TRIGGER_PATH) as Area2D
	var player: Node = tree.get_first_node_in_group("player")
	assert_true(trigger != null, "Bedroom silence trigger is missing in level_01_start")
	assert_true(player != null, "Player node was not found after level load")
	if trigger != null and player != null:
		assert_true(trigger.overlaps_body(player), "Player should spawn inside the bedroom silence trigger")

	assert_true(MusicManager != null, "MusicManager autoload is missing")
	if MusicManager != null:
		assert_true(MusicManager.is_ambient_music_suppressed(), "Ambient suppression must be active at level start in bedroom")
		var sample: Dictionary = _sample_active_ambient_volume(MusicManager)
		assert_true(not bool(sample.get("found", false)), "Ambient playback must stay stopped while bedroom suppression is active")

	await _cleanup_runtime_state(tree)
	return get_failures()

func _scene_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _open_main_menu_scene(tree: SceneTree) -> void:
	var err: int = tree.change_scene_to_file(MAIN_MENU_SCENE_PATH)
	assert_true(err == OK, "Failed to open main menu scene: %s" % MAIN_MENU_SCENE_PATH)
	if err != OK:
		return
	await tree.process_frame
	await tree.process_frame

func _prepare_new_game_state(menu: Node) -> void:
	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()
	if GameState != null:
		GameState.set_meta("startup_disclaimer_shown_session", true)
	menu.set("new_game_sleep_sfx", null)

func _await_scene_path_or_timeout(tree: SceneTree, expected_scene_path: String, timeout_sec: float) -> bool:
	var timeout: SceneTreeTimer = tree.create_timer(timeout_sec, true)
	var tick: SceneTreeTimer = tree.create_timer(0.05, true)
	while timeout.time_left > 0.0:
		var scene: Node = tree.current_scene
		if scene != null and scene.scene_file_path == expected_scene_path:
			return true
		await tick.timeout
		tick = tree.create_timer(0.05, true)
	return false

func _sample_active_ambient_volume(music_manager: Node) -> Dictionary:
	var result: Dictionary = {"found": false, "loudest_db": -80.0}
	var source_kind := String(music_manager.get("_current_source_kind"))
	if source_kind != "ambient":
		return result
	var current_stream: Variant = music_manager.call("get_current_stream")
	var active_player: AudioStreamPlayer = music_manager.get("_active_player") as AudioStreamPlayer
	var inactive_player: AudioStreamPlayer = music_manager.get("_inactive_player") as AudioStreamPlayer
	var players: Array[AudioStreamPlayer] = []
	if active_player != null:
		players.append(active_player)
	if inactive_player != null:
		players.append(inactive_player)
	for player in players:
		if not player.playing:
			continue
		if current_stream != null and player.stream != current_stream:
			continue
		result["found"] = true
		result["loudest_db"] = maxf(float(result["loudest_db"]), player.volume_db)
	return result

func _await_bedroom_state(tree: SceneTree, scene: Node, timeout_sec: float) -> bool:
	var timeout: SceneTreeTimer = tree.create_timer(timeout_sec, true)
	var tick: SceneTreeTimer = tree.create_timer(0.05, true)
	while timeout.time_left > 0.0:
		var trigger: Area2D = scene.get_node_or_null(BEDROOM_TRIGGER_PATH) as Area2D
		var player: Node = tree.get_first_node_in_group("player")
		var has_overlap := trigger != null and player != null and trigger.overlaps_body(player)
		var ambient_suppressed := MusicManager != null and MusicManager.is_ambient_music_suppressed()
		if has_overlap and ambient_suppressed:
			return true
		await tick.timeout
		tick = tree.create_timer(0.05, true)
	return false

func _cleanup_runtime_state(tree: SceneTree) -> void:
	if MusicManager != null:
		MusicManager.set_ambient_music_suppressed(self, false, 0.0)
		MusicManager.clear_stack()
		MusicManager.stop_music(0.0)
	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()
	var scene: Node = tree.current_scene
	if scene != null:
		scene.queue_free()
		await tree.process_frame
