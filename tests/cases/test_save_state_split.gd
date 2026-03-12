extends "res://tests/test_case.gd"

const TEST_SCENE_PATH := "res://levels/cycles/level_06_corridordistortion.tscn"

func run() -> Array[String]:
	assert_true(GameState != null, "GameState autoload is missing")
	assert_true(CycleState != null, "CycleState autoload is missing")
	if GameState == null or CycleState == null:
		return get_failures()

	GameState.reset_run()
	GameState.set_current_scene_path(TEST_SCENE_PATH)
	GameState.unlock_flashlight()
	GameState.mark_unique_feeding_intro_played()
	CycleState.mark_lab_completed("save_lab_alpha")
	CycleState.mark_ate()
	CycleState.set_phase(CycleState.Phase.DISTORTED)

	var config := ConfigFile.new()
	GameState.write_save_data(config)
	CycleState.write_save_data(config)

	GameState.reset_run()
	GameState.load_save_data(config)
	CycleState.load_save_data(config)

	assert_true(GameState.is_flashlight_unlocked(), "Persistent flashlight unlock must restore from GameState section")
	assert_eq(GameState.get_last_scene_path(), TEST_SCENE_PATH, "GameState must restore last scene path")
	assert_true(GameState.is_unique_feeding_intro_played(), "Persistent run progress must restore from GameState section")
	assert_true(CycleState.is_lab_completed("save_lab_alpha"), "Cycle lab completion must restore from CycleState section")
	assert_true(CycleState.has_eaten_this_cycle(), "Cycle eat flag must restore from CycleState section")
	assert_eq(int(CycleState.phase), int(CycleState.Phase.DISTORTED), "Cycle phase must restore from CycleState section")

	GameState.next_cycle()
	assert_true(GameState.is_flashlight_unlocked(), "Persistent GameState unlock must survive next_cycle")
	assert_true(not CycleState.has_completed_any_lab(), "Cycle lab data must not leak into the next cycle")
	assert_true(not CycleState.has_eaten_this_cycle(), "Cycle eat flag must not leak into the next cycle")
	assert_eq(int(CycleState.phase), int(CycleState.Phase.NORMAL), "Cycle phase must reset on next_cycle")

	GameState.reset_run()
	return get_failures()
