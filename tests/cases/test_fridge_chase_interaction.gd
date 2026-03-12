extends "res://tests/test_case.gd"

class FridgeProbe:
	extends "res://objects/interactable/fridge/fridge.gd"

	var feeding_started: bool = false

	func _is_chase_active() -> bool:
		return true

	func _start_feeding_process() -> void:
		feeding_started = true

class TeleportFridgeProbe:
	extends "res://objects/interactable/fridge/fridge.gd"

	var chase_cleared: bool = false

	func _clear_chase_after_teleport_success() -> void:
		chase_cleared = true

func run() -> Array[String]:
	_test_fridge_is_not_blocked_during_chase()
	_test_teleport_fridge_clears_chase_state()
	return get_failures()

func _test_fridge_is_not_blocked_during_chase() -> void:
	assert_true(CycleState != null, "CycleState autoload is missing")
	if CycleState == null:
		return

	CycleState.reset_cycle_state()

	var fridge := FridgeProbe.new()
	fridge.require_access_code = false
	fridge.require_lab_completion = false
	fridge.call("_on_interact")
	
	assert_true(fridge.feeding_started, "Fridge interaction should proceed even if chase is active")
	fridge.free()

func _test_teleport_fridge_clears_chase_state() -> void:
	assert_true(CycleState != null, "CycleState autoload is missing")
	if CycleState == null:
		return

	CycleState.reset_cycle_state()

	var fridge := TeleportFridgeProbe.new()
	fridge.enable_teleport = true
	fridge.call("_finish_feeding_logic")

	assert_true(fridge.chase_cleared, "Teleporting fridge must stop chase state after successful feeding")
	fridge.free()
