extends "res://tests/test_case.gd"

class FridgeProbe:
	extends "res://objects/interactable/fridge/fridge.gd"

	var feeding_started: bool = false

	func _is_chase_active() -> bool:
		return true

	func _start_feeding_process() -> void:
		feeding_started = true

func run() -> Array[String]:
	_test_fridge_is_not_blocked_during_chase()
	return get_failures()

func _test_fridge_is_not_blocked_during_chase() -> void:
	assert_true(GameState != null, "GameState autoload is missing")
	if GameState == null:
		return

	GameState.ate_this_cycle = false
	GameState.lab_done = true

	var fridge := FridgeProbe.new()
	fridge.require_access_code = false
	fridge.require_lab_completion = false
	fridge.call("_on_interact")

	assert_true(fridge.feeding_started, "Fridge interaction should proceed even if chase is active")
	fridge.free()
