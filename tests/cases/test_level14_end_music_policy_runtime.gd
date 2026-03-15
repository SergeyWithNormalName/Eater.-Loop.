extends "res://tests/test_case.gd"

const LEVEL_SCENE_PATH := "res://levels/cycles/level_14_end.tscn"
const CREDITS_SCENE_PATH := "res://levels/endings/ending_credits.tscn"
const RUNNER_MUSIC_PATH := "res://music/RunnerHARDMUSIC.wav"
const CARRIED_MUSIC_PATH := "res://music/StressMusic.wav"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	assert_true(MusicManager != null, "MusicManager autoload is missing")
	if tree == null or MusicManager == null:
		return get_failures()

	var level_scene := assert_loads(LEVEL_SCENE_PATH) as PackedScene
	var credits_scene := assert_loads(CREDITS_SCENE_PATH) as PackedScene
	var runner_music := assert_loads(RUNNER_MUSIC_PATH) as AudioStream
	var carried_music := assert_loads(CARRIED_MUSIC_PATH) as AudioStream
	assert_true(level_scene != null, "level_14_end scene failed to load")
	assert_true(credits_scene != null, "Ending credits scene failed to load")
	assert_true(runner_music != null, "Runner credits music failed to load")
	assert_true(carried_music != null, "Carried-over music stream failed to load")
	if level_scene == null or credits_scene == null or runner_music == null or carried_music == null:
		return get_failures()

	_reset_music_manager()
	MusicManager.start_event_music(self, carried_music, 0.0)
	MusicManager.set_chase_music_source(self, true, runner_music, -8.0, 0.0)
	await tree.process_frame
	await tree.process_frame

	var level := level_scene.instantiate()
	tree.root.add_child(level)
	await tree.process_frame
	await tree.process_frame

	var active_player := MusicManager.get("_active_player") as AudioStreamPlayer
	var stack_value: Variant = MusicManager.get("_stack")
	assert_true(active_player == null or not active_player.playing, "level_14_end must stop carried base/event music on ready")
	assert_true(MusicManager.get_current_stream() == null, "level_14_end must not keep university theme or other carried music")
	assert_true(stack_value is Array and (stack_value as Array).is_empty(), "level_14_end must clear stacked priority music sources")
	assert_true(not MusicManager.is_chase_active(), "level_14_end must also stop carried chase music")

	var credits := credits_scene.instantiate()
	tree.root.add_child(credits)
	await tree.process_frame
	await tree.process_frame
	var credits_music := credits.get("credits_music") as AudioStream
	assert_true(credits_music != null, "Ending credits must have a music stream assigned")
	if credits_music != null:
		assert_eq(credits_music.resource_path, RUNNER_MUSIC_PATH, "Ending credits must use RunnerHARDMUSIC for both endings")
	assert_eq(MusicManager.get_current_stream(), runner_music, "Ending credits must start RunnerHARDMUSIC on scene ready")
	assert_eq(String(MusicManager.get("_current_source_kind")), MusicManager.SOURCE_KIND_EVENT, "Ending credits music must bypass ambient suppression by using a non-ambient source kind")

	credits.queue_free()
	level.queue_free()
	await tree.process_frame
	_reset_music_manager()
	return get_failures()

func _reset_music_manager() -> void:
	if MusicManager == null:
		return
	MusicManager.clear_chase_music_sources(0.0)
	MusicManager.clear_stack()
	MusicManager.reset_base_music_state()
