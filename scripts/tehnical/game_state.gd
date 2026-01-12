extends Node

signal lab_completed(quest_id: String)
signal phone_picked_changed
signal fridge_interacted_changed
signal cycle_changed(new_cycle: int)
signal electricity_changed(is_on: bool)

enum Phase { NORMAL, DISTORTED }

var cycle: int = 1
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

func next_cycle() -> void:
	cycle += 1
	ate_this_cycle = false
	fridge_interacted = false
	set_phase(Phase.NORMAL)

func emit_cycle_changed() -> void:
	cycle_changed.emit(cycle)

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

func reset_cycle_state() -> void:
	ate_this_cycle = false
	fridge_interacted = false
	phone_picked = false
	pending_sleep_spawn = false
	set_phase(Phase.NORMAL)

func reset_run() -> void:
	cycle = 1
	ate_this_cycle = false
	completed_labs = []
	phone_picked = false
	fridge_interacted = false
	pending_sleep_spawn = false
	electricity_on = true
	set_phase(Phase.NORMAL)
	last_scene_path = ""
	has_active_run = false
