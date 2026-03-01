extends "res://tests/test_case.gd"

const StalkerMotionAudioComponentScript := preload("res://enemies/stalker/stalker_motion_audio_component.gd")

func run() -> Array[String]:
	_test_step_and_scrape_tracks_are_separated()
	_test_tracks_respect_animation_filters()
	return get_failures()

func _test_step_and_scrape_tracks_are_separated() -> void:
	var component := StalkerMotionAudioComponentScript.new()
	component.step_animation_name = &"walk"
	component.scrape_animation_name = &"walk"
	component.step_frame_indices = [2, 4]
	component.scrape_frame_indices = [1, 3]
	component.step_sounds = []
	component.scrape_sounds = []
	component.refresh_configuration()

	var counters := {"step": 0, "scrape": 0}
	component.step_triggered.connect(func(_frame_index: int, _animation_name: StringName) -> void:
		counters["step"] = int(counters["step"]) + 1
	)
	component.scrape_triggered.connect(func(_frame_index: int, _animation_name: StringName) -> void:
		counters["scrape"] = int(counters["scrape"]) + 1
	)

	component.handle_animation_frame(&"walk", 1)
	component.handle_animation_frame(&"walk", 2)
	component.handle_animation_frame(&"walk", 3)
	component.handle_animation_frame(&"walk", 0)

	var step_count := int(counters["step"])
	var scrape_count := int(counters["scrape"])
	assert_eq(step_count, 2, "Step track must trigger only on configured step frames (got %d)" % step_count)
	assert_eq(scrape_count, 2, "Scrape track must trigger only on configured scrape frames (got %d)" % scrape_count)

	component.free()

func _test_tracks_respect_animation_filters() -> void:
	var component := StalkerMotionAudioComponentScript.new()
	component.step_animation_name = &"walk"
	component.scrape_animation_name = &"walk"
	component.step_frame_indices = [1]
	component.scrape_frame_indices = [1]
	component.step_sounds = []
	component.scrape_sounds = []
	component.refresh_configuration()

	var counters := {"step": 0, "scrape": 0}
	component.step_triggered.connect(func(_frame_index: int, _animation_name: StringName) -> void:
		counters["step"] = int(counters["step"]) + 1
	)
	component.scrape_triggered.connect(func(_frame_index: int, _animation_name: StringName) -> void:
		counters["scrape"] = int(counters["scrape"]) + 1
	)

	component.handle_animation_frame(&"idle", 1)
	component.handle_animation_frame(&"idle", 0)
	var step_count := int(counters["step"])
	var scrape_count := int(counters["scrape"])
	assert_eq(step_count, 0, "Step track must ignore non-walk animations")
	assert_eq(scrape_count, 0, "Scrape track must ignore non-walk animations")

	component.handle_animation_frame(&"walk", 1)
	component.handle_animation_frame(&"walk", 0)
	step_count = int(counters["step"])
	scrape_count = int(counters["scrape"])
	assert_eq(step_count, 1, "Step track must trigger when the walk animation reaches step frame (got %d)" % step_count)
	assert_eq(scrape_count, 1, "Scrape track must trigger when the walk animation reaches scrape frame (got %d)" % scrape_count)

	component.free()
