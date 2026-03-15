extends Node

const SAVE_PATH := "user://run_save.cfg"
const GAME_SECTION := "game"
const CHECKPOINT_SECTION := "checkpoint"
const CHECKPOINT_KIND_NONE := ""
const CHECKPOINT_KIND_LEVEL_START := "level_start"
const CHECKPOINT_KIND_FRIDGE := "fridge"

var unique_feeding_intro_played: bool = false
var last_scene_path: String = ""
var has_active_run: bool = false
var flashlight_unlocked: bool = false
var running_unlocked: bool = false

var checkpoint_scene_path: String = ""
var checkpoint_kind: String = CHECKPOINT_KIND_NONE
var checkpoint_game_state: Dictionary = {}
var checkpoint_cycle_state: Dictionary = {}
var checkpoint_director_state: Dictionary = {}
var checkpoint_scene_state: Dictionary = {}
var checkpoint_participant_paths: PackedStringArray = PackedStringArray()

func _ready() -> void:
	if _saves_enabled():
		restore_autosave_run()

func next_cycle() -> void:
	if not flashlight_unlocked and CycleState != null and CycleState.has_method("has_flashlight_for_current_cycle"):
		if bool(CycleState.has_flashlight_for_current_cycle()):
			flashlight_unlocked = true
	clear_checkpoint_state()
	if CycleState != null and CycleState.has_method("next_cycle"):
		CycleState.next_cycle()
	_save_run_state()

func mark_unique_feeding_intro_played() -> void:
	if unique_feeding_intro_played:
		return
	unique_feeding_intro_played = true
	_save_run_state()

func is_unique_feeding_intro_played() -> bool:
	return unique_feeding_intro_played

func set_current_scene_path(path: String) -> void:
	if path == "":
		return
	last_scene_path = path
	has_active_run = true
	_save_run_state()

func reset_cycle_state() -> void:
	clear_checkpoint_state()
	if CycleState != null and CycleState.has_method("reset_cycle_state"):
		CycleState.reset_cycle_state()
	_save_run_state()

func set_phase(new_phase: int) -> void:
	if CycleState != null and CycleState.has_method("set_phase"):
		CycleState.set_phase(new_phase)

func mark_ate() -> void:
	if CycleState != null and CycleState.has_method("mark_ate"):
		CycleState.mark_ate()

func has_eaten_this_cycle() -> bool:
	if CycleState != null and CycleState.has_method("has_eaten_this_cycle"):
		return bool(CycleState.has_eaten_this_cycle())
	return false

func mark_phone_picked() -> void:
	if CycleState != null and CycleState.has_method("mark_phone_picked"):
		CycleState.mark_phone_picked()

func mark_fridge_interacted() -> void:
	if CycleState != null and CycleState.has_method("mark_fridge_interacted"):
		CycleState.mark_fridge_interacted()

func is_fridge_interacted() -> bool:
	if CycleState != null and CycleState.has_method("is_fridge_interacted"):
		return bool(CycleState.is_fridge_interacted())
	return false

func queue_sleep_spawn() -> void:
	if CycleState != null and CycleState.has_method("queue_sleep_spawn"):
		CycleState.queue_sleep_spawn()

func consume_pending_sleep_spawn() -> bool:
	if CycleState != null and CycleState.has_method("consume_pending_sleep_spawn"):
		return bool(CycleState.consume_pending_sleep_spawn())
	return false

func queue_respawn_blackout() -> void:
	if CycleState != null and CycleState.has_method("queue_respawn_blackout"):
		CycleState.queue_respawn_blackout()

func consume_pending_respawn_blackout() -> bool:
	if CycleState != null and CycleState.has_method("consume_pending_respawn_blackout"):
		return bool(CycleState.consume_pending_respawn_blackout())
	return false

func reset_run() -> void:
	unique_feeding_intro_played = false
	flashlight_unlocked = false
	running_unlocked = false
	last_scene_path = ""
	has_active_run = false
	clear_checkpoint_state()
	if CycleState != null and CycleState.has_method("reset_runtime_state_only"):
		CycleState.reset_runtime_state_only()
	_save_run_state()

func autosave_run() -> void:
	_save_run_state()

func capture_level_start_checkpoint(scene: Node) -> void:
	_capture_checkpoint(scene, CHECKPOINT_KIND_LEVEL_START)

func capture_fridge_checkpoint(scene: Node) -> void:
	_capture_checkpoint(scene, CHECKPOINT_KIND_FRIDGE)

func has_respawn_checkpoint() -> bool:
	return checkpoint_kind != CHECKPOINT_KIND_NONE \
		and checkpoint_scene_path != "" \
		and not checkpoint_game_state.is_empty() \
		and not checkpoint_cycle_state.is_empty()

func restore_respawn_checkpoint() -> bool:
	if not has_respawn_checkpoint():
		return false
	_import_runtime_state(checkpoint_game_state)
	_apply_cycle_checkpoint_state(checkpoint_cycle_state)
	return true

func apply_checkpoint_to_scene(scene: Node) -> bool:
	if scene == null:
		return false
	if not has_respawn_checkpoint():
		return false
	var scene_path := _resolve_scene_path(scene)
	if scene_path == "" or scene_path != checkpoint_scene_path:
		return false

	var preserve_sleep_spawn := false
	var preserve_respawn_blackout := false
	if CycleState != null:
		if CycleState.has_method("has_pending_sleep_spawn"):
			preserve_sleep_spawn = bool(CycleState.has_pending_sleep_spawn())
		if CycleState.has_method("has_pending_respawn_blackout"):
			preserve_respawn_blackout = bool(CycleState.has_pending_respawn_blackout())

	_import_runtime_state(checkpoint_game_state)
	_apply_cycle_checkpoint_state(checkpoint_cycle_state)
	if preserve_sleep_spawn and CycleState != null and CycleState.has_method("queue_sleep_spawn"):
		CycleState.queue_sleep_spawn()
	if preserve_respawn_blackout and CycleState != null and CycleState.has_method("queue_respawn_blackout"):
		CycleState.queue_respawn_blackout()

	_apply_scene_checkpoint_state(scene)

	if GameDirector != null and GameDirector.has_method("apply_checkpoint_state"):
		GameDirector.apply_checkpoint_state(checkpoint_director_state)
	if MusicManager != null and MusicManager.has_method("clear_chase_music_sources"):
		MusicManager.clear_chase_music_sources(0.0)
	return true

func clear_checkpoint_state() -> void:
	checkpoint_scene_path = ""
	checkpoint_kind = CHECKPOINT_KIND_NONE
	checkpoint_game_state = {}
	checkpoint_cycle_state = {}
	checkpoint_director_state = {}
	checkpoint_scene_state = {}
	checkpoint_participant_paths = PackedStringArray()

func restore_autosave_run() -> bool:
	if not _saves_enabled():
		return false
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	load_save_data(config)
	if CycleState != null and CycleState.has_method("load_save_data"):
		CycleState.load_save_data(config)
	return true

func _save_run_state() -> void:
	if not _saves_enabled():
		return
	var config := ConfigFile.new()
	write_save_data(config)
	if CycleState != null and CycleState.has_method("write_save_data"):
		CycleState.write_save_data(config)
	config.save(SAVE_PATH)

func _load_run_state() -> void:
	restore_autosave_run()

func get_last_scene_path() -> String:
	return last_scene_path

func has_active_run_state() -> bool:
	return has_active_run

func is_flashlight_unlocked() -> bool:
	return flashlight_unlocked

func unlock_flashlight() -> void:
	if flashlight_unlocked:
		return
	flashlight_unlocked = true
	_save_run_state()

func write_save_data(config: ConfigFile) -> void:
	if config == null:
		return
	config.set_value(GAME_SECTION, "last_scene_path", last_scene_path)
	config.set_value(GAME_SECTION, "has_active_run", has_active_run)
	config.set_value(GAME_SECTION, "unique_feeding_intro_played", unique_feeding_intro_played)
	config.set_value(GAME_SECTION, "flashlight_unlocked", flashlight_unlocked)
	config.set_value(GAME_SECTION, "running_unlocked", running_unlocked)
	config.set_value(CHECKPOINT_SECTION, "scene_path", checkpoint_scene_path)
	config.set_value(CHECKPOINT_SECTION, "kind", checkpoint_kind)
	config.set_value(CHECKPOINT_SECTION, "game_state", checkpoint_game_state)
	config.set_value(CHECKPOINT_SECTION, "cycle_state", checkpoint_cycle_state)
	config.set_value(CHECKPOINT_SECTION, "director_state", checkpoint_director_state)
	config.set_value(CHECKPOINT_SECTION, "scene_state", checkpoint_scene_state)
	config.set_value(CHECKPOINT_SECTION, "participant_paths", checkpoint_participant_paths)

func load_save_data(config: ConfigFile) -> void:
	if config == null:
		return
	last_scene_path = str(config.get_value(GAME_SECTION, "last_scene_path", ""))
	has_active_run = bool(config.get_value(GAME_SECTION, "has_active_run", false))
	unique_feeding_intro_played = bool(config.get_value(GAME_SECTION, "unique_feeding_intro_played", false))
	flashlight_unlocked = bool(config.get_value(GAME_SECTION, "flashlight_unlocked", false))
	running_unlocked = bool(config.get_value(GAME_SECTION, "running_unlocked", false))
	checkpoint_scene_path = str(config.get_value(CHECKPOINT_SECTION, "scene_path", ""))
	checkpoint_kind = str(config.get_value(CHECKPOINT_SECTION, "kind", CHECKPOINT_KIND_NONE))
	var raw_game_state: Variant = config.get_value(CHECKPOINT_SECTION, "game_state", {})
	checkpoint_game_state = raw_game_state if raw_game_state is Dictionary else {}
	var raw_cycle_state: Variant = config.get_value(CHECKPOINT_SECTION, "cycle_state", {})
	checkpoint_cycle_state = raw_cycle_state if raw_cycle_state is Dictionary else {}
	var raw_director_state: Variant = config.get_value(CHECKPOINT_SECTION, "director_state", {})
	checkpoint_director_state = raw_director_state if raw_director_state is Dictionary else {}
	var raw_scene_state: Variant = config.get_value(CHECKPOINT_SECTION, "scene_state", {})
	checkpoint_scene_state = raw_scene_state if raw_scene_state is Dictionary else {}
	var raw_paths: Variant = config.get_value(CHECKPOINT_SECTION, "participant_paths", PackedStringArray())
	if raw_paths is PackedStringArray:
		checkpoint_participant_paths = raw_paths
	elif raw_paths is Array:
		checkpoint_participant_paths = PackedStringArray(raw_paths)
	else:
		checkpoint_participant_paths = PackedStringArray()

func _capture_checkpoint(scene: Node, kind: String) -> void:
	if scene == null:
		return
	var scene_path := _resolve_scene_path(scene)
	if scene_path == "":
		return
	checkpoint_scene_path = scene_path
	checkpoint_kind = kind
	checkpoint_game_state = _export_runtime_state()
	checkpoint_cycle_state = _export_cycle_state()
	checkpoint_director_state = _export_director_state()
	checkpoint_participant_paths = PackedStringArray(_collect_checkpoint_participant_paths(scene))
	checkpoint_scene_state = _capture_scene_checkpoint_state(scene, checkpoint_participant_paths)
	_save_run_state()

func _resolve_scene_path(scene: Node) -> String:
	if scene == null:
		return ""
	var scene_path := String(scene.scene_file_path)
	if scene_path != "":
		return scene_path
	return last_scene_path

func _export_runtime_state() -> Dictionary:
	return {
		"last_scene_path": last_scene_path,
		"has_active_run": has_active_run,
		"unique_feeding_intro_played": unique_feeding_intro_played,
		"flashlight_unlocked": flashlight_unlocked,
		"running_unlocked": running_unlocked,
	}

func _import_runtime_state(state: Dictionary) -> void:
	last_scene_path = str(state.get("last_scene_path", last_scene_path))
	has_active_run = bool(state.get("has_active_run", has_active_run))
	unique_feeding_intro_played = bool(state.get("unique_feeding_intro_played", unique_feeding_intro_played))
	flashlight_unlocked = bool(state.get("flashlight_unlocked", flashlight_unlocked))
	running_unlocked = bool(state.get("running_unlocked", running_unlocked))

func _export_cycle_state() -> Dictionary:
	if CycleState != null and CycleState.has_method("export_checkpoint_state"):
		var state: Variant = CycleState.export_checkpoint_state()
		if state is Dictionary:
			return state
	return {}

func _apply_cycle_checkpoint_state(state: Dictionary) -> void:
	if CycleState != null and CycleState.has_method("apply_checkpoint_state"):
		CycleState.apply_checkpoint_state(state)

func _export_director_state() -> Dictionary:
	if GameDirector != null and GameDirector.has_method("capture_checkpoint_state"):
		var state: Variant = GameDirector.capture_checkpoint_state()
		if state is Dictionary:
			return state
	return {}

func _collect_checkpoint_participant_paths(scene: Node) -> Array[String]:
	var paths: Array[String] = []
	var seen: Dictionary = {}
	var tree := get_tree()
	if tree == null:
		return paths
	for node in tree.get_nodes_in_group(CheckpointStateUtils.CHECKPOINT_STATEFUL_GROUP):
		if node == null or not is_instance_valid(node):
			continue
		if node == scene:
			continue
		if not scene.is_ancestor_of(node):
			continue
		var path := CheckpointStateUtils.get_scene_relative_path(scene, node)
		if path == "" or seen.has(path):
			continue
		seen[path] = true
		paths.append(path)
	for path_value in checkpoint_participant_paths:
		var existing_path := str(path_value)
		if existing_path == "" or seen.has(existing_path):
			continue
		seen[existing_path] = true
		paths.append(existing_path)
	paths.sort()
	return paths

func _capture_scene_checkpoint_state(scene: Node, participant_paths: PackedStringArray) -> Dictionary:
	var scene_state: Dictionary = {}
	for path_value in participant_paths:
		var path_text := str(path_value)
		if path_text == "":
			continue
		var node := scene.get_node_or_null(NodePath(path_text))
		if node == null:
			scene_state[path_text] = {"exists": false}
			continue
		scene_state[path_text] = {
			"exists": true,
			"snapshot": CheckpointStateUtils.capture_node_snapshot(node),
		}
	return scene_state

func _apply_scene_checkpoint_state(scene: Node) -> void:
	for path_value in checkpoint_participant_paths:
		var path_text := str(path_value)
		if path_text == "":
			continue
		var entry_raw: Variant = checkpoint_scene_state.get(path_text, {})
		if not (entry_raw is Dictionary):
			continue
		var entry := entry_raw as Dictionary
		var node := scene.get_node_or_null(NodePath(path_text))
		if node == null:
			continue
		if not bool(entry.get("exists", true)):
			CheckpointStateUtils.remove_absent_node(node)
			continue
		var snapshot_raw: Variant = entry.get("snapshot", {})
		if snapshot_raw is Dictionary:
			CheckpointStateUtils.apply_node_snapshot(node, snapshot_raw)

func _saves_enabled() -> bool:
	# Disable persistence while testing in the editor.
	return not OS.has_feature("editor")
