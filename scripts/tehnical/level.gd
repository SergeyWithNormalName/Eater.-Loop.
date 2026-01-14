extends Node2D

## Cycle number for this level.
@export var cycle_number: int = 1
## Timer duration in seconds (0 = disabled).
@export var timer_duration: float = 0.0

func get_cycle_number() -> int:
	return cycle_number

func get_timer_duration() -> float:
	return timer_duration
