extends "res://tests/test_case.gd"

const AMBIENT_STREAM_PATH := "res://music/InsideAmbient.wav"
const DISTORTION_STREAM_PATH := "res://music/StressMusic.wav"
const MUSIC_MANAGER_PATH := "res://levels/music_manager.gd"

func run() -> Array[String]:
	assert_true(MusicManager != null, "MusicManager autoload is missing")
	if MusicManager == null:
		return get_failures()
	assert_true(_ensure_music_manager_players(), "MusicManager players must be initialized")
	if not _ensure_music_manager_players():
		return get_failures()

	var ambient_stream := load(AMBIENT_STREAM_PATH) as AudioStream
	var distortion_stream := load(DISTORTION_STREAM_PATH) as AudioStream
	assert_true(ambient_stream != null, "Ambient test stream failed to load")
	assert_true(distortion_stream != null, "Distortion test stream failed to load")
	if ambient_stream == null or distortion_stream == null:
		return get_failures()

	await _test_pending_ambient_does_not_override_distortion(ambient_stream, distortion_stream)
	_test_pause_resume_restores_playback_position()
	_cleanup_music_manager()
	return get_failures()

func _test_pending_ambient_does_not_override_distortion(ambient_stream: AudioStream, distortion_stream: AudioStream) -> void:
	_cleanup_music_manager()
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return

	MusicManager.play_ambient_music(ambient_stream, 0.0)
	await tree.process_frame
	MusicManager.set_ambient_music_suppressed(self, true, 0.0)
	await tree.process_frame
	assert_eq(MusicManager.get("_pending_ambient_stream"), ambient_stream, "Ambient stream must stay queued while suppression is active")

	MusicManager.start_distortion_music(self, distortion_stream, 0.0)
	await tree.process_frame
	MusicManager.set_ambient_music_suppressed(self, false, 0.0)
	await tree.process_frame
	await tree.process_frame

	assert_eq(MusicManager.get_current_stream(), distortion_stream, "Pending ambient must not replace active distortion music")
	assert_eq(String(MusicManager.get("_current_source_kind")), MusicManager.SOURCE_KIND_DISTORTION, "Distortion source kind must stay active until distortion music stops")
	assert_eq(MusicManager.get("_pending_ambient_stream"), ambient_stream, "Ambient stream must remain pending until higher-priority music stops")

	MusicManager.stop_distortion_music(self, 0.0)
	await tree.process_frame
	await tree.process_frame
	assert_eq(MusicManager.get_current_stream(), ambient_stream, "Pending ambient must resume after distortion music stops")
	assert_eq(String(MusicManager.get("_current_source_kind")), MusicManager.SOURCE_KIND_AMBIENT, "Ambient source kind must restore after distortion music stops")

func _test_pause_resume_restores_playback_position() -> void:
	var script_text := FileAccess.get_file_as_string(MUSIC_MANAGER_PATH)
	assert_true(script_text != "", "Failed to read music_manager.gd")
	if script_text == "":
		return
	assert_true(script_text.find("_base_pause_position = resume_position_override if resume_position_override >= 0.0 else _get_playback_position(player)") != -1, "Pause path must store an explicit playback position before stopping the base player")
	assert_true(script_text.find("player.play()\n\t_seek_if_possible(player, resume_position)") != -1, "Resume path must restart the base player and seek back to the stored position")
	assert_true(script_text.find("_base_pause_position = 0.0") != -1, "Resume path must clear the stored paused position after restoring playback")

func _cleanup_music_manager() -> void:
	if MusicManager == null:
		return
	MusicManager.set_ambient_music_suppressed(self, false, 0.0)
	MusicManager.clear_chase_music_sources(0.0)
	MusicManager.clear_stack()
	MusicManager.reset_base_music_state()

func _ensure_music_manager_players() -> bool:
	var from_player: AudioStreamPlayer = MusicManager.get("_player_a") as AudioStreamPlayer
	var to_player: AudioStreamPlayer = MusicManager.get("_player_b") as AudioStreamPlayer
	if from_player != null and to_player != null:
		return true
	if MusicManager.has_method("_ready"):
		MusicManager.call("_ready")
	from_player = MusicManager.get("_player_a") as AudioStreamPlayer
	to_player = MusicManager.get("_player_b") as AudioStreamPlayer
	return from_player != null and to_player != null
