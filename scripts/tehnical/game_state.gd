extends Node

@warning_ignore("unused_signal")
signal lab_completed(quest_id: String)
signal phone_picked_changed
signal fridge_interacted_changed
signal electricity_changed(is_on: bool)

enum Phase { NORMAL, DISTORTED }

const SAVE_PATH := "user://run_save.cfg"

var phase: Phase = Phase.NORMAL # Было просто phase
var ate_this_cycle: bool = false
var completed_labs: Array[String] = []
var phone_picked: bool = false
var fridge_interacted: bool = false
var pending_sleep_spawn: bool = false
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
	pending_sleep_spawn = false
	set_phase(Phase.NORMAL)
	_save_run_state()

func reset_run() -> void:
	ate_this_cycle = false
	completed_labs = []
	phone_picked = false
	fridge_interacted = false
	pending_sleep_spawn = false
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
	config.set_value("run", "completed_labs", completed_labs)
	config.set_value("run", "phone_picked", phone_picked)
	config.set_value("run", "fridge_interacted", fridge_interacted)
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
	completed_labs = _coerce_string_array(config.get_value("run", "completed_labs", completed_labs))
	phone_picked = bool(config.get_value("run", "phone_picked", phone_picked))
	fridge_interacted = bool(config.get_value("run", "fridge_interacted", fridge_interacted))
	ate_this_cycle = bool(config.get_value("run", "ate_this_cycle", ate_this_cycle))
	electricity_on = bool(config.get_value("run", "electricity_on", electricity_on))
	pending_sleep_spawn = false
	set_phase(Phase.NORMAL)

func _coerce_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray:
		for item in value:
			result.append(item)
		return result
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _saves_enabled() -> bool:
	# Disable persistence while testing in the editor.
	return not OS.has_feature("editor")
