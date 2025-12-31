extends Node

# ===== enum ТОЛЬКО ЗДЕСЬ, В САМОМ ВЕРХУ =====
enum Phase {
	NORMAL,
	DISTORTED
}

# ===== ПЕРЕМЕННЫЕ =====
@export var cycle: int = 1
var ate_this_cycle: bool = false
var phase: Phase = Phase.NORMAL

# ===== МЕТОДЫ =====
func set_phase(new_phase: Phase) -> void:
	phase = new_phase

func next_cycle() -> void:
	cycle += 1
	ate_this_cycle = false

func mark_ate() -> void:
	ate_this_cycle = true
