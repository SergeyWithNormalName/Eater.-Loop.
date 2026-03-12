extends Node

signal lab_completed
signal lab_completed_with_id(lab_id: String)
signal ate_this_cycle_changed(is_ate: bool)
signal phone_picked_changed
signal fridge_interacted_changed
signal electricity_changed(is_on: bool)
signal flashlight_collected_this_cycle_changed(is_collected: bool)
signal cycle_state_reset

enum Phase { NORMAL, DISTORTED }

const SAVE_SECTION := "cycle"

var phase: Phase = Phase.NORMAL
var ate_this_cycle: bool = false
var lab_done: bool = false
var completed_labs: PackedStringArray = PackedStringArray()
var phone_picked: bool = false
var fridge_interacted: bool = false
var pending_sleep_spawn: bool = false
var pending_respawn_blackout: bool = false
var flashlight_collected_this_cycle: bool = false

var _electricity_on: bool = true
var electricity_on: bool:
	set(value):
		if _electricity_on == value:
			return
		_electricity_on = value
		electricity_changed.emit(_electricity_on)
	get:
		return _electricity_on

func set_phase(new_phase: Phase) -> void:
	phase = new_phase

func next_cycle() -> void:
	_reset_cycle_state_internal(true)

func reset_cycle_state() -> void:
	_reset_cycle_state_internal(true)

func reset_runtime_state_only() -> void:
	_reset_cycle_state_internal(false)

func mark_ate() -> void:
	if ate_this_cycle:
		return
	ate_this_cycle = true
	ate_this_cycle_changed.emit(ate_this_cycle)
	_autosave_run()

func has_eaten_this_cycle() -> bool:
	return ate_this_cycle

func mark_phone_picked() -> void:
	if phone_picked:
		return
	phone_picked = true
	phone_picked_changed.emit()
	_autosave_run()

func mark_fridge_interacted() -> void:
	if fridge_interacted:
		return
	fridge_interacted = true
	fridge_interacted_changed.emit()
	_autosave_run()

func is_fridge_interacted() -> bool:
	return fridge_interacted

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
		_autosave_run()

func is_lab_completed(lab_id: String = "") -> bool:
	var normalized_id := lab_id.strip_edges()
	if normalized_id == "":
		return lab_done
	return completed_labs.has(normalized_id)

func has_completed_any_lab() -> bool:
	return lab_done

func has_completed_all_labs(required_lab_ids: PackedStringArray) -> bool:
	if required_lab_ids.is_empty():
		return has_completed_any_lab()
	for lab_id in required_lab_ids:
		var normalized_id := String(lab_id).strip_edges()
		if normalized_id == "":
			continue
		if not completed_labs.has(normalized_id):
			return false
	return true

func collect_flashlight_for_cycle() -> void:
	if flashlight_collected_this_cycle:
		return
	flashlight_collected_this_cycle = true
	flashlight_collected_this_cycle_changed.emit(true)
	_autosave_run()

func clear_flashlight_for_cycle() -> void:
	if not flashlight_collected_this_cycle:
		return
	flashlight_collected_this_cycle = false
	flashlight_collected_this_cycle_changed.emit(false)
	_autosave_run()

func has_flashlight_for_current_cycle() -> bool:
	if flashlight_collected_this_cycle:
		return true
	if GameState != null and GameState.has_method("is_flashlight_unlocked"):
		return bool(GameState.is_flashlight_unlocked())
	return false

func queue_sleep_spawn() -> void:
	if pending_sleep_spawn:
		return
	pending_sleep_spawn = true
	_autosave_run()

func has_pending_sleep_spawn() -> bool:
	return pending_sleep_spawn

func consume_pending_sleep_spawn() -> bool:
	if not pending_sleep_spawn:
		return false
	pending_sleep_spawn = false
	_autosave_run()
	return true

func queue_respawn_blackout() -> void:
	if pending_respawn_blackout:
		return
	pending_respawn_blackout = true
	_autosave_run()

func has_pending_respawn_blackout() -> bool:
	return pending_respawn_blackout

func consume_pending_respawn_blackout() -> bool:
	if not pending_respawn_blackout:
		return false
	pending_respawn_blackout = false
	_autosave_run()
	return true

func write_save_data(config: ConfigFile) -> void:
	if config == null:
		return
	config.set_value(SAVE_SECTION, "phase", int(phase))
	config.set_value(SAVE_SECTION, "ate_this_cycle", ate_this_cycle)
	config.set_value(SAVE_SECTION, "lab_done", lab_done)
	config.set_value(SAVE_SECTION, "completed_labs", completed_labs)
	config.set_value(SAVE_SECTION, "phone_picked", phone_picked)
	config.set_value(SAVE_SECTION, "fridge_interacted", fridge_interacted)
	config.set_value(SAVE_SECTION, "pending_sleep_spawn", pending_sleep_spawn)
	config.set_value(SAVE_SECTION, "pending_respawn_blackout", pending_respawn_blackout)
	config.set_value(SAVE_SECTION, "electricity_on", electricity_on)
	config.set_value(SAVE_SECTION, "flashlight_collected_this_cycle", flashlight_collected_this_cycle)

func export_checkpoint_state() -> Dictionary:
	return {
		"phase": int(phase),
		"ate_this_cycle": ate_this_cycle,
		"lab_done": lab_done,
		"completed_labs": completed_labs,
		"phone_picked": phone_picked,
		"fridge_interacted": fridge_interacted,
		"pending_sleep_spawn": pending_sleep_spawn,
		"pending_respawn_blackout": pending_respawn_blackout,
		"electricity_on": electricity_on,
		"flashlight_collected_this_cycle": flashlight_collected_this_cycle,
	}

func apply_checkpoint_state(state: Dictionary) -> void:
	if state.is_empty():
		_reset_cycle_state_internal(false)
		return
	var raw_phase := int(state.get("phase", int(Phase.NORMAL)))
	if raw_phase < int(Phase.NORMAL) or raw_phase > int(Phase.DISTORTED):
		raw_phase = int(Phase.NORMAL)
	phase = raw_phase
	ate_this_cycle = bool(state.get("ate_this_cycle", false))
	lab_done = bool(state.get("lab_done", false))
	var completed_labs_raw: Variant = state.get("completed_labs", [])
	completed_labs = PackedStringArray(_coerce_string_array(completed_labs_raw))
	if not lab_done and not completed_labs.is_empty():
		lab_done = true
	phone_picked = bool(state.get("phone_picked", false))
	fridge_interacted = bool(state.get("fridge_interacted", false))
	pending_sleep_spawn = bool(state.get("pending_sleep_spawn", false))
	pending_respawn_blackout = bool(state.get("pending_respawn_blackout", false))
	electricity_on = bool(state.get("electricity_on", true))
	flashlight_collected_this_cycle = bool(state.get("flashlight_collected_this_cycle", false))

func load_save_data(config: ConfigFile) -> void:
	if config == null:
		_reset_cycle_state_internal(false)
		return
	phase = Phase.NORMAL
	if config.has_section_key(SAVE_SECTION, "phase"):
		var raw_phase := int(config.get_value(SAVE_SECTION, "phase", int(Phase.NORMAL)))
		if raw_phase >= int(Phase.NORMAL) and raw_phase <= int(Phase.DISTORTED):
			phase = raw_phase
	ate_this_cycle = bool(config.get_value(SAVE_SECTION, "ate_this_cycle", false))
	lab_done = bool(config.get_value(SAVE_SECTION, "lab_done", false))
	var completed_labs_raw: Variant = config.get_value(SAVE_SECTION, "completed_labs", [])
	completed_labs = PackedStringArray(_coerce_string_array(completed_labs_raw))
	if not lab_done and not completed_labs.is_empty():
		lab_done = true
	phone_picked = bool(config.get_value(SAVE_SECTION, "phone_picked", false))
	fridge_interacted = bool(config.get_value(SAVE_SECTION, "fridge_interacted", false))
	pending_sleep_spawn = bool(config.get_value(SAVE_SECTION, "pending_sleep_spawn", false))
	pending_respawn_blackout = bool(config.get_value(SAVE_SECTION, "pending_respawn_blackout", false))
	electricity_on = bool(config.get_value(SAVE_SECTION, "electricity_on", true))
	flashlight_collected_this_cycle = bool(config.get_value(SAVE_SECTION, "flashlight_collected_this_cycle", false))

func _reset_cycle_state_internal(autosave_after_reset: bool) -> void:
	phase = Phase.NORMAL
	ate_this_cycle = false
	lab_done = false
	completed_labs = PackedStringArray()
	phone_picked = false
	fridge_interacted = false
	pending_sleep_spawn = false
	pending_respawn_blackout = false
	electricity_on = true
	flashlight_collected_this_cycle = false
	ate_this_cycle_changed.emit(false)
	fridge_interacted_changed.emit()
	phone_picked_changed.emit()
	flashlight_collected_this_cycle_changed.emit(false)
	cycle_state_reset.emit()
	if autosave_after_reset:
		_autosave_run()

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

func _autosave_run() -> void:
	if GameState == null:
		return
	if GameState.has_method("autosave_run"):
		GameState.autosave_run()
