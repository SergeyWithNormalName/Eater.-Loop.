extends "res://tests/test_case.gd"

const AMBIENT_STREAM_PATH := "res://music/InsideAmbient.wav"
const EVENT_STREAM_PATH := "res://music/StressMusic.wav"
const DISTORTION_STREAM_PATH := "res://music/DrainMusic.wav"
const ALT_STREAM_PATH := "res://music/MusicForLabs.wav"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	assert_true(MusicManager != null, "MusicManager autoload is missing")
	if tree == null or MusicManager == null:
		return get_failures()
	assert_true(_ensure_music_manager_players(), "MusicManager players must be initialized")
	if not _ensure_music_manager_players():
		return get_failures()

	var ambient_stream := load(AMBIENT_STREAM_PATH) as AudioStream
	var event_stream := load(EVENT_STREAM_PATH) as AudioStream
	var distortion_stream := load(DISTORTION_STREAM_PATH) as AudioStream
	var alt_stream := load(ALT_STREAM_PATH) as AudioStream
	assert_true(ambient_stream != null, "Ambient test stream failed to load")
	assert_true(event_stream != null, "Event test stream failed to load")
	assert_true(distortion_stream != null, "Distortion test stream failed to load")
	assert_true(alt_stream != null, "Alternate test stream failed to load")
	if ambient_stream == null or event_stream == null or distortion_stream == null or alt_stream == null:
		return get_failures()

	await _test_reset_all_music_state(tree, ambient_stream, event_stream, distortion_stream)
	_test_same_stream_crossfade_update(alt_stream, event_stream)
	await _test_duplicate_event_source_restart(tree, ambient_stream, event_stream, distortion_stream)
	await _test_duplicate_distortion_source_restart(tree, ambient_stream, distortion_stream, alt_stream)
	_cleanup_music_manager()
	return get_failures()

func _test_reset_all_music_state(tree: SceneTree, ambient_stream: AudioStream, event_stream: AudioStream, distortion_stream: AudioStream) -> void:
	_cleanup_music_manager()
	MusicManager.play_ambient_music(ambient_stream, 0.0)
	await tree.process_frame
	MusicManager.start_event_music(self, event_stream, 0.0)
	MusicManager.set_ambient_music_suppressed(self, true, 0.0)
	MusicManager.set_chase_music_source(self, true, distortion_stream, -8.0, 0.0)
	MusicManager.start_pause_menu_music(distortion_stream, 0.0)
	await tree.process_frame
	MusicManager.reset_all_music_state()
	await tree.process_frame

	var state := MusicManager.get_music_debug_state()
	assert_eq(String(state.get("current_stream_path", "")), "", "Full reset must clear current stream path")
	assert_eq(String(state.get("current_source_kind", "")), MusicManager.SOURCE_KIND_GENERIC, "Full reset must clear current source kind")
	assert_eq(int(state.get("stack_depth", -1)), 0, "Full reset must empty the music stack")
	assert_true(not bool(state.get("pause_menu_active", true)), "Full reset must clear pause-menu activity")
	assert_true(not bool(state.get("base_pause_active", true)), "Full reset must clear base pause activity")
	assert_eq(String(state.get("pause_transition_state", "")), MusicManager.PAUSE_TRANSITION_IDLE, "Full reset must return pause transition state to idle")
	assert_true(not bool(state.get("chase_active", true)), "Full reset must clear chase activity")
	assert_true(not bool(state.get("ambient_suppressed", true)), "Full reset must clear ambient suppression")
	assert_true(not bool(state.get("base_player_a", {}).get("playing", true)), "Full reset must stop base player A")
	assert_true(not bool(state.get("base_player_b", {}).get("playing", true)), "Full reset must stop base player B")
	assert_true(not bool(state.get("pause_player", {}).get("playing", true)), "Full reset must stop the pause player")
	assert_true(not bool(state.get("runner_player", {}).get("playing", true)), "Full reset must stop the chase player")
	assert_true((MusicManager.get("_event_sources") as Dictionary).is_empty(), "Full reset must clear event sources")
	assert_true((MusicManager.get("_distortion_sources") as Dictionary).is_empty(), "Full reset must clear distortion sources")

func _test_same_stream_crossfade_update(target_stream: AudioStream, previous_stream: AudioStream) -> void:
	_cleanup_music_manager()
	var from_player := MusicManager.get("_player_a") as AudioStreamPlayer
	var to_player := MusicManager.get("_player_b") as AudioStreamPlayer
	assert_true(from_player != null and to_player != null, "MusicManager base players are not initialized")
	if from_player == null or to_player == null:
		return

	from_player.stream = previous_stream
	from_player.volume_db = -12.0
	from_player.play()
	to_player.stream = target_stream
	to_player.volume_db = -40.0
	to_player.play()

	MusicManager.set("_active_player", from_player)
	MusicManager.set("_inactive_player", to_player)
	MusicManager.set("_current_stream", target_stream)
	MusicManager.set("_current_source_id", 4242)
	MusicManager.set("_current_source_kind", MusicManager.SOURCE_KIND_EVENT)
	MusicManager.set("_base_volume_db", -14.0)
	MusicManager.set("_is_ducked", false)
	MusicManager.set("_chase_base_muted", false)
	MusicManager.set("_is_crossfading", true)
	MusicManager.set("_crossfade_from", from_player)
	MusicManager.set("_crossfade_to", to_player)
	MusicManager.set("_crossfade_target_db", -14.0)

	MusicManager.play_music(target_stream, 0.0, -9.0, 0.0, 999.0, 4242, MusicManager.SOURCE_KIND_EVENT)

	assert_true(MusicManager.get("_active_player") == to_player, "Same-stream update during crossfade must retarget the real destination player")
	assert_true(to_player.playing, "Crossfade destination player must stay active after same-stream update")
	assert_true(not from_player.playing, "Crossfade source player must stop after same-stream update settles")
	assert_true(absf(to_player.volume_db - -9.0) < 0.05, "Same-stream update must apply the new target volume to the destination player")

func _test_duplicate_event_source_restart(tree: SceneTree, ambient_stream: AudioStream, event_stream: AudioStream, alternate_event_stream: AudioStream) -> void:
	_cleanup_music_manager()
	var event_source := Node.new()
	tree.root.add_child(event_source)
	MusicManager.play_ambient_music(ambient_stream, 0.0)
	await tree.process_frame
	MusicManager.start_event_music(event_source, event_stream, 0.0)
	await tree.process_frame
	assert_eq(int(MusicManager.get_music_debug_state().get("stack_depth", -1)), 1, "First event start must push only one stack entry")
	MusicManager.start_event_music(event_source, alternate_event_stream, 0.0)
	await tree.process_frame
	var updated_state := MusicManager.get_music_debug_state()
	assert_eq(int(updated_state.get("stack_depth", -1)), 1, "Restarting one event source must not duplicate stack ownership")
	assert_eq(String(updated_state.get("current_stream_path", "")), DISTORTION_STREAM_PATH, "Restarting one event source must replace the active event stream")
	MusicManager.stop_event_music(event_source, 0.0)
	await tree.process_frame
	var restored_state := MusicManager.get_music_debug_state()
	assert_eq(String(restored_state.get("current_source_kind", "")), MusicManager.SOURCE_KIND_AMBIENT, "Stopping the event source must restore ambient music")
	assert_eq(String(restored_state.get("current_stream_path", "")), AMBIENT_STREAM_PATH, "Stopping the event source must restore the ambient stream")
	assert_eq(int(restored_state.get("stack_depth", -1)), 0, "Stopping the event source must leave no extra stack entries")
	event_source.queue_free()
	await tree.process_frame

func _test_duplicate_distortion_source_restart(tree: SceneTree, ambient_stream: AudioStream, distortion_stream: AudioStream, alternate_distortion_stream: AudioStream) -> void:
	_cleanup_music_manager()
	var distortion_source := Node.new()
	tree.root.add_child(distortion_source)
	MusicManager.play_ambient_music(ambient_stream, 0.0)
	await tree.process_frame
	MusicManager.start_distortion_music(distortion_source, distortion_stream, 0.0)
	await tree.process_frame
	assert_eq(int(MusicManager.get_music_debug_state().get("stack_depth", -1)), 1, "First distortion start must push only one stack entry")
	MusicManager.start_distortion_music(distortion_source, alternate_distortion_stream, 0.0)
	await tree.process_frame
	var updated_state := MusicManager.get_music_debug_state()
	assert_eq(int(updated_state.get("stack_depth", -1)), 1, "Restarting one distortion source must not duplicate stack ownership")
	assert_eq(String(updated_state.get("current_stream_path", "")), ALT_STREAM_PATH, "Restarting one distortion source must replace the active distortion stream")
	MusicManager.stop_distortion_music(distortion_source, 0.0)
	await tree.process_frame
	var restored_state := MusicManager.get_music_debug_state()
	assert_eq(String(restored_state.get("current_source_kind", "")), MusicManager.SOURCE_KIND_AMBIENT, "Stopping the distortion source must restore ambient music")
	assert_eq(String(restored_state.get("current_stream_path", "")), AMBIENT_STREAM_PATH, "Stopping the distortion source must restore the ambient stream")
	assert_eq(int(restored_state.get("stack_depth", -1)), 0, "Stopping the distortion source must leave no extra stack entries")
	distortion_source.queue_free()
	await tree.process_frame

func _cleanup_music_manager() -> void:
	if MusicManager == null:
		return
	MusicManager.set_ambient_music_suppressed(self, false, 0.0)
	if MusicManager.has_method("reset_all_music_state"):
		MusicManager.reset_all_music_state()
	else:
		MusicManager.clear_chase_music_sources(0.0)
		MusicManager.clear_stack()
		MusicManager.reset_base_music_state()

func _ensure_music_manager_players() -> bool:
	var from_player := MusicManager.get("_player_a") as AudioStreamPlayer
	var to_player := MusicManager.get("_player_b") as AudioStreamPlayer
	if from_player != null and to_player != null:
		return true
	if MusicManager.has_method("_ready"):
		MusicManager.call("_ready")
	from_player = MusicManager.get("_player_a") as AudioStreamPlayer
	to_player = MusicManager.get("_player_b") as AudioStreamPlayer
	return from_player != null and to_player != null
