extends "res://tests/test_case.gd"

const FridgeScript := preload("res://objects/interactable/fridge/fridge.gd")

func run() -> Array[String]:
	assert_true(CycleState != null, "CycleState autoload is missing")
	if CycleState == null:
		return get_failures()

	CycleState.reset_cycle_state()

	var fridge := FridgeScript.new()
	fridge.require_access_code = false
	fridge.require_lab_completion = false
	fridge.use_locked_visual_after_eating = true

	assert_true(bool(fridge.call("_is_available_for_player")), "Fridge should stay visually available before eating")

	CycleState.mark_ate()
	assert_true(not bool(fridge.call("_is_available_for_player")), "Fridge should switch to unavailable visuals after eating when the inspector flag is enabled")

	fridge.use_locked_visual_after_eating = false
	assert_true(bool(fridge.call("_is_available_for_player")), "Fridge should stay visually available after eating when the inspector flag is disabled")

	fridge.free()
	CycleState.reset_cycle_state()
	return get_failures()
