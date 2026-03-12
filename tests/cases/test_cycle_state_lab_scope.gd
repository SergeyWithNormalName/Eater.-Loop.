extends "res://tests/test_case.gd"

const FridgeScript := preload("res://objects/interactable/fridge/fridge.gd")

func run() -> Array[String]:
	assert_true(GameState != null, "GameState autoload is missing")
	assert_true(CycleState != null, "CycleState autoload is missing")
	if GameState == null or CycleState == null:
		return get_failures()

	GameState.reset_run()

	var fridge := FridgeScript.new()
	fridge.require_lab_completion = true

	assert_true(not bool(fridge.call("_has_required_lab_completion")), "Fridge must require a lab before current-cycle progress exists")

	CycleState.mark_lab_completed("cycle_lab_a")
	assert_true(CycleState.has_completed_any_lab(), "CycleState must remember completed lab in the current cycle")
	assert_true(bool(fridge.call("_has_required_lab_completion")), "Fridge must open after lab completion in the same cycle")

	CycleState.reset_cycle_state()
	assert_true(not CycleState.has_completed_any_lab(), "Cycle reset must clear current-cycle lab completion")
	assert_true(CycleState.completed_labs.is_empty(), "Cycle reset must clear completed lab IDs")
	assert_true(not bool(fridge.call("_has_required_lab_completion")), "Fridge must require the lab again after cycle reset")

	CycleState.mark_lab_completed("cycle_lab_b")
	assert_true(CycleState.is_lab_completed("cycle_lab_b"), "CycleState must track newly completed labs after reset")

	GameState.next_cycle()
	assert_true(not CycleState.has_completed_any_lab(), "Advancing to the next cycle must clear previous cycle lab progress")
	assert_true(CycleState.completed_labs.is_empty(), "Advancing to the next cycle must clear completed lab IDs")
	assert_true(not CycleState.is_lab_completed("cycle_lab_b"), "A lab from one cycle must not affect the next cycle")

	fridge.free()
	GameState.reset_run()
	return get_failures()
