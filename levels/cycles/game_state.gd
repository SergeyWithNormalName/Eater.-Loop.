extends Node

const SAVE_PATH := "user://run_save.cfg"
var unique_feeding_intro_played: bool = false
var last_scene_path: String = ""
var has_active_run: bool = false
var flashlight_unlocked: bool = false
var running_unlocked: bool = false

func _ready() -> void:
	if _saves_enabled():
		restore_autosave_run()

func next_cycle() -> void:
	if not flashlight_unlocked and CycleState != null and CycleState.has_method("has_flashlight_for_current_cycle"):
		if bool(CycleState.has_flashlight_for_current_cycle()):
			flashlight_unlocked = true
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
	if CycleState != null and CycleState.has_method("reset_runtime_state_only"):
		CycleState.reset_runtime_state_only()
	_save_run_state()

func autosave_run() -> void:
	_save_run_state()

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
	config.set_value("game", "last_scene_path", last_scene_path)
	config.set_value("game", "has_active_run", has_active_run)
	config.set_value("game", "unique_feeding_intro_played", unique_feeding_intro_played)
	config.set_value("game", "flashlight_unlocked", flashlight_unlocked)
	config.set_value("game", "running_unlocked", running_unlocked)

func load_save_data(config: ConfigFile) -> void:
	if config == null:
		return
	last_scene_path = str(config.get_value("game", "last_scene_path", ""))
	has_active_run = bool(config.get_value("game", "has_active_run", false))
	unique_feeding_intro_played = bool(config.get_value("game", "unique_feeding_intro_played", false))
	flashlight_unlocked = bool(config.get_value("game", "flashlight_unlocked", false))
	running_unlocked = bool(config.get_value("game", "running_unlocked", false))

func _coerce_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	if value is PackedStringArray:
		for item in value:
			var text := str(item)
			if seen.has(text):
				continue
			seen[text] = true
			result.append(text)
		return result
	if value is Array:
		for item in value:
			var text := str(item)
			if seen.has(text):
				continue
			seen[text] = true
			result.append(text)
	return result

func _saves_enabled() -> bool:
	# Disable persistence while testing in the editor.
	return not OS.has_feature("editor")
