extends "res://tests/test_case.gd"

const LEVEL_SCENE_PATH := "res://levels/cycles/level_05_sql.tscn"
const FIRST_FRIDGE_PATH := "Hall/InteractableObjects/Fridge"
const LAPTOP_PATH := "Bedroom/InteractableObjects/Laptop"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	assert_true(MinigameController != null, "MinigameController autoload is missing")
	assert_true(GameState != null, "GameState autoload is missing")
	assert_true(CycleState != null, "CycleState autoload is missing")
	if tree == null or MinigameController == null or GameState == null or CycleState == null:
		return get_failures()

	await _reset_runtime_state(tree, null)

	var level_scene := assert_loads(LEVEL_SCENE_PATH) as PackedScene
	assert_true(level_scene != null, "Level 05 scene failed to load")
	if level_scene == null:
		return get_failures()

	var level := level_scene.instantiate()
	tree.root.add_child(level)
	await tree.process_frame
	await tree.process_frame

	var fridge := level.get_node_or_null(FIRST_FRIDGE_PATH)
	var laptop := level.get_node_or_null(LAPTOP_PATH)
	assert_true(fridge != null, "Primary fridge is missing in level_05_sql")
	assert_true(laptop != null, "Laptop is missing in level_05_sql")
	if fridge == null or laptop == null:
		await _reset_runtime_state(tree, level)
		return get_failures()

	fridge.request_interact()
	await tree.process_frame
	await tree.process_frame
	var prelab_code_lock := fridge.get("_current_minigame") as Node
	if prelab_code_lock != null:
		if prelab_code_lock.has_method("on_minigame_cancel"):
			prelab_code_lock.call("on_minigame_cancel")
		elif prelab_code_lock.is_inside_tree():
			prelab_code_lock.queue_free()
		await tree.process_frame
		await tree.process_frame

	laptop.call("_start_lab_minigame")
	await tree.process_frame
	await tree.process_frame

	var lab_minigame := laptop.get("_current_minigame") as Node
	assert_true(lab_minigame != null, "Laptop must open the SQL lab minigame after the fridge interaction")
	if lab_minigame == null:
		await _reset_runtime_state(tree, level)
		return get_failures()

	await _await_minigame_transition_idle(tree)

	lab_minigame.call("finish_game", true)
	await _await_note_opened(tree)
	await tree.process_frame
	await tree.process_frame

	if UIMessage != null and UIMessage.has_method("hide_note"):
		UIMessage.hide_note()
	await _await_note_closed(tree)
	await _await_minigame_transition_idle(tree)
	await tree.process_frame
	await tree.process_frame

	assert_true(not bool(MinigameController.get("_transition_active")), "Minigame transition state must clear after the lab note closes")
	assert_true(not tree.paused, "Closing the post-lab note must return the game from pause before the fridge retry")

	fridge.request_interact()
	await tree.process_frame
	await tree.process_frame
	await _await_minigame_transition_idle(tree)
	await tree.process_frame
	await tree.process_frame

	var code_lock := fridge.get("_current_minigame") as Node
	assert_true(code_lock != null, "Primary fridge must open the code lock after the SQL lab")
	if code_lock != null:
		assert_true(MinigameController.is_active(code_lock), "Code lock must become the active minigame after the SQL lab")
		if code_lock is CanvasItem:
			assert_true((code_lock as CanvasItem).visible, "Code lock UI must stay visible after the SQL lab note closes")

	await _reset_runtime_state(tree, level)
	return get_failures()

func _reset_runtime_state(tree: SceneTree, level: Node) -> void:
	tree.paused = false
	if UIMessage != null:
		if UIMessage.has_method("set_screen_dark"):
			UIMessage.set_screen_dark(false)
		if UIMessage.has_method("hide_subtitle"):
			UIMessage.hide_subtitle()
		UIMessage.set("_is_viewing_note", false)
		UIMessage.set("_note_transition_active", false)
		UIMessage.set("_queued_subtitle_text", "")
		UIMessage.set("_queued_subtitle_duration", -1.0)
		UIMessage.set("_queued_dialogue_voice", null)
		UIMessage.set("_queued_dialogue_volume_db", 0.0)
		UIMessage.set("_queued_dialogue_pitch_scale", 1.0)
		var note_bg := UIMessage.get("_note_bg") as CanvasItem
		if note_bg != null:
			note_bg.visible = false
		var note_image := UIMessage.get("_note_image") as CanvasItem
		if note_image != null:
			note_image.visible = false
	if MinigameController != null and MinigameController.has_method("_force_clear_active_state"):
		MinigameController.call("_force_clear_active_state")
	if MinigameController != null:
		MinigameController.set("_transition_active", false)
		MinigameController.set("_transition_queue", [])
	var minigame_nodes := tree.get_nodes_in_group("minigame_ui")
	for node in minigame_nodes:
		if node != null and is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	if level != null and is_instance_valid(level) and level.is_inside_tree():
		level.queue_free()
	await tree.process_frame
	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()
	elif CycleState != null and CycleState.has_method("reset_runtime_state_only"):
		CycleState.reset_runtime_state_only()

func _await_note_transition_idle(tree: SceneTree, timeout: float = 2.0) -> void:
	var elapsed := 0.0
	while UIMessage != null and bool(UIMessage.get("_note_transition_active")) and elapsed < timeout:
		await tree.create_timer(0.05, true).timeout
		elapsed += 0.05

func _await_note_opened(tree: SceneTree, timeout: float = 2.0) -> void:
	var elapsed := 0.0
	while UIMessage != null and not bool(UIMessage.get("_is_viewing_note")) and elapsed < timeout:
		await tree.create_timer(0.05, true).timeout
		elapsed += 0.05
	await _await_note_transition_idle(tree, timeout)

func _await_note_closed(tree: SceneTree, timeout: float = 2.0) -> void:
	var elapsed := 0.0
	while UIMessage != null and bool(UIMessage.get("_is_viewing_note")) and elapsed < timeout:
		if not bool(UIMessage.get("_note_transition_active")):
			break
		await tree.create_timer(0.05, true).timeout
		elapsed += 0.05
	await _await_note_transition_idle(tree, timeout)
	elapsed = 0.0
	while UIMessage != null and bool(UIMessage.get("_is_viewing_note")) and elapsed < timeout:
		await tree.create_timer(0.05, true).timeout
		elapsed += 0.05

func _await_minigame_transition_idle(tree: SceneTree, timeout: float = 2.0) -> void:
	var elapsed := 0.0
	while MinigameController != null and bool(MinigameController.get("_transition_active")) and elapsed < timeout:
		await tree.create_timer(0.05, true).timeout
		elapsed += 0.05
