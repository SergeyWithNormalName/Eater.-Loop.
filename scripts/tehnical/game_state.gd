extends Node

signal lab_completed(quest_id: String)

enum Phase { NORMAL, DISTORTED }

var cycle: int = 1
var phase: Phase = Phase.NORMAL # Было просто phase
var ate_this_cycle: bool = false
var completed_labs: Array[String] = []

func next_cycle() -> void:
	cycle += 1
	ate_this_cycle = false
	set_phase(Phase.NORMAL)

func mark_ate() -> void:
	ate_this_cycle = true

# Добавляем этот метод, чтобы GameDirector мог менять фазу
func set_phase(new_phase: Phase) -> void:
	phase = new_phase
