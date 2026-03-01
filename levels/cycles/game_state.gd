extends Node

@warning_ignore("unused_signal")
signal lab_completed
signal lab_completed_with_id(lab_id: String)
signal phone_picked_changed
signal fridge_interacted_changed
signal electricity_changed(is_on: bool)

enum Phase { NORMAL, DISTORTED }

const SAVE_PATH := "user://run_save.cfg"

var phase: Phase = Phase.NORMAL # Было просто phase
var ate_this_cycle: bool = false
var lab_done: bool = false
var completed_labs: PackedStringArray = PackedStringArray()
var phone_picked: bool = false
var fridge_interacted: bool = false
var unique_feeding_intro_played: bool = false
var pending_sleep_spawn: bool = false
var pending_respawn_blackout: bool = false
var last_scene_path: String = ""
var has_active_run: bool = false
var _electricity_on: bool = true
var electricity_on: bool:
	set(value):
		if _electricity_on == value:
			return
		_electricity_on = value
		electricity_changed.emit(_electricity_on)
	get:
		return _electricity_on

func _ready() -> void:
	if _saves_enabled():
		_load_run_state()

func next_cycle() -> void:
	ate_this_cycle = false
	fridge_interacted = false
	lab_done = false
	completed_labs = PackedStringArray()
	pending_respawn_blackout = false
	set_phase(Phase.NORMAL)
	_save_run_state()

func mark_ate() -> void:
	ate_this_cycle = true

func mark_phone_picked() -> void:
	if phone_picked:
		return
	phone_picked = true
	phone_picked_changed.emit()

func mark_fridge_interacted() -> void:
	if fridge_interacted:
		return
	fridge_interacted = true
	fridge_interacted_changed.emit()

func mark_unique_feeding_intro_played() -> void:
	if unique_feeding_intro_played:
		return
	unique_feeding_intro_played = true
	_save_run_state()

func is_unique_feeding_intro_played() -> bool:
	return unique_feeding_intro_played

# Добавляем этот метод, чтобы GameDirector мог менять фазу
func set_phase(new_phase: Phase) -> void:
	phase = new_phase

func set_current_scene_path(path: String) -> void:
	if path == "":
		return
	last_scene_path = path
	has_active_run = true
	_save_run_state()

func reset_cycle_state() -> void:
	ate_this_cycle = false
	fridge_interacted = false
	phone_picked = false
	lab_done = false
	completed_labs = PackedStringArray()
	pending_sleep_spawn = false
	pending_respawn_blackout = false
	set_phase(Phase.NORMAL)
	_save_run_state()

func reset_run() -> void:
	ate_this_cycle = false
	lab_done = false
	completed_labs = PackedStringArray()
	phone_picked = false
	fridge_interacted = false
	unique_feeding_intro_played = false
	pending_sleep_spawn = false
	pending_respawn_blackout = false
	electricity_on = true
	set_phase(Phase.NORMAL)
	last_scene_path = ""
	has_active_run = false
	_save_run_state()

func _save_run_state() -> void:
	if not _saves_enabled():
		return
	var config := ConfigFile.new()
	config.set_value("run", "last_scene_path", last_scene_path)
	config.set_value("run", "has_active_run", has_active_run)
	config.set_value("run", "lab_done", lab_done)
	config.set_value("run", "completed_labs", completed_labs)
	config.set_value("run", "phone_picked", phone_picked)
	config.set_value("run", "fridge_interacted", fridge_interacted)
	config.set_value("run", "unique_feeding_intro_played", unique_feeding_intro_played)
	config.set_value("run", "ate_this_cycle", ate_this_cycle)
	config.set_value("run", "electricity_on", electricity_on)
	config.save(SAVE_PATH)

func _load_run_state() -> void:
	if not _saves_enabled():
		return
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	last_scene_path = str(config.get_value("run", "last_scene_path", last_scene_path))
	has_active_run = bool(config.get_value("run", "has_active_run", has_active_run))
	lab_done = bool(config.get_value("run", "lab_done", lab_done))
	var completed_labs_raw: Variant = config.get_value("run", "completed_labs", [])
	completed_labs = PackedStringArray(_coerce_string_array(completed_labs_raw))
	if not lab_done and not completed_labs.is_empty():
		lab_done = true
	phone_picked = bool(config.get_value("run", "phone_picked", phone_picked))
	fridge_interacted = bool(config.get_value("run", "fridge_interacted", fridge_interacted))
	unique_feeding_intro_played = bool(config.get_value("run", "unique_feeding_intro_played", unique_feeding_intro_played))
	ate_this_cycle = bool(config.get_value("run", "ate_this_cycle", ate_this_cycle))
	electricity_on = bool(config.get_value("run", "electricity_on", electricity_on))
	pending_sleep_spawn = false
	pending_respawn_blackout = false
	set_phase(Phase.NORMAL)

func mark_lab_completed(lab_id: String = "") -> void:
	var normalized_id := lab_id.strip_edges()
	var did_add_specific := false
	if normalized_id != "" and not completed_labs.has(normalized_id):
		completed_labs.append(normalized_id)
		did_add_specific = true
		lab_completed_with_id.emit(normalized_id)
	if not lab_done:
		lab_done = true
		lab_completed.emit()
	if did_add_specific or normalized_id == "":
		_save_run_state()

func is_lab_completed(lab_id: String = "") -> bool:
	var normalized_id := lab_id.strip_edges()
	if normalized_id == "":
		return lab_done
	return completed_labs.has(normalized_id)

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
