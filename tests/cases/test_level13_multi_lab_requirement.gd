extends "res://tests/test_case.gd"

const LEVEL_SCENE_PATH := "res://levels/cycles/level_13_STU_3.tscn"
const EXPECTED_LAB_IDS := [
	"level_13_stu_3_laptop_1",
	"level_13_stu_3_laptop_2",
	"level_13_stu_3_laptop_3",
	"level_13_stu_3_laptop_4"
]

func run() -> Array[String]:
	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()

	var level_scene := assert_loads(LEVEL_SCENE_PATH) as PackedScene
	assert_true(level_scene != null, "Level 13 scene failed to load")
	if level_scene == null:
		return get_failures()

	var level := level_scene.instantiate()
	var fridge := level.get_node_or_null("Stolovaya/InteractableObjects/Fridge")
	assert_true(fridge != null, "Level 13 fridge node is missing")
	if fridge == null:
		level.free()
		return get_failures()

	assert_true(bool(fridge.get("require_lab_completion")), "Level 13 fridge must require labs in the current cycle")
	var required_ids := fridge.get("required_lab_completion_ids") as PackedStringArray
	assert_eq(required_ids.size(), EXPECTED_LAB_IDS.size(), "Level 13 fridge must require the full set of lab IDs")
	for expected_id in EXPECTED_LAB_IDS:
		assert_true(required_ids.has(expected_id), "Level 13 fridge must include required lab ID: %s" % expected_id)

	assert_true(not bool(fridge.call("_has_required_lab_completion")), "Fridge must stay locked before completing all required labs")

	for index in range(EXPECTED_LAB_IDS.size() - 1):
		CycleState.mark_lab_completed(EXPECTED_LAB_IDS[index])
		assert_true(not bool(fridge.call("_has_required_lab_completion")), "Fridge must remain locked until every required lab is completed")

	CycleState.mark_lab_completed(EXPECTED_LAB_IDS[EXPECTED_LAB_IDS.size() - 1])
	assert_true(bool(fridge.call("_has_required_lab_completion")), "Fridge must unlock only after all required labs are completed in the same cycle")

	level.free()
	if GameState != null and GameState.has_method("reset_run"):
		GameState.reset_run()
	return get_failures()
