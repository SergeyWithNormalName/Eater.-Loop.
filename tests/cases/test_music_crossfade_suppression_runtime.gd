extends "res://tests/test_case.gd"

const MENU_STREAM_PATH := "res://music/StressMusic.wav"
const AMBIENT_STREAM_PATH := "res://music/InsideAmbient.wav"
const MUTED_THRESHOLD_DB := -70.0

func run() -> Array[String]:
	assert_true(MusicManager != null, "MusicManager autoload is missing")
	if MusicManager == null:
		return get_failures()
	var players_ready := _ensure_music_manager_players()
	assert_true(players_ready, "MusicManager base players are not initialized")
	if not players_ready:
		return get_failures()

	var menu_stream: AudioStream = load(MENU_STREAM_PATH) as AudioStream
	var ambient_stream: AudioStream = load(AMBIENT_STREAM_PATH) as AudioStream
	assert_true(menu_stream != null, "Failed to load menu stream: %s" % MENU_STREAM_PATH)
	assert_true(ambient_stream != null, "Failed to load ambient stream: %s" % AMBIENT_STREAM_PATH)
	if menu_stream == null or ambient_stream == null:
		return get_failures()

	var from_player: AudioStreamPlayer = MusicManager.get("_player_a") as AudioStreamPlayer
	var to_player: AudioStreamPlayer = MusicManager.get("_player_b") as AudioStreamPlayer
	assert_true(from_player != null and to_player != null, "MusicManager base players are not initialized")
	if from_player == null or to_player == null:
		return get_failures()

	_setup_synthetic_crossfade_state(from_player, to_player, menu_stream, ambient_stream)
	MusicManager.set_ambient_music_suppressed(self, true, 0.2)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()
	await tree.create_timer(0.45, true).timeout

	assert_true(to_player.playing, "Crossfade target player must stay playing after suppression")
	assert_true(to_player.volume_db <= MUTED_THRESHOLD_DB, "Crossfade target ambient must be muted after suppression (got %.2f dB)" % to_player.volume_db)

	_cleanup_music_manager_state(from_player, to_player)
	return get_failures()

func _setup_synthetic_crossfade_state(from_player: AudioStreamPlayer, to_player: AudioStreamPlayer, menu_stream: AudioStream, ambient_stream: AudioStream) -> void:
	MusicManager.set_ambient_music_suppressed(self, false, 0.0)
	MusicManager.clear_stack()
	MusicManager.stop_music(0.0)

	from_player.stream_paused = false
	to_player.stream_paused = false

	from_player.stream = menu_stream
	from_player.volume_db = -12.0
	from_player.play()

	to_player.stream = ambient_stream
	to_player.volume_db = -50.0
	to_player.play()

	MusicManager.set("_active_player", from_player)
	MusicManager.set("_inactive_player", to_player)
	MusicManager.set("_current_stream", ambient_stream)
	MusicManager.set("_current_source_kind", MusicManager.SOURCE_KIND_AMBIENT)
	MusicManager.set("_base_volume_db", -16.5)
	MusicManager.set("_is_ducked", false)
	MusicManager.set("_chase_base_muted", false)
	MusicManager.set("_is_crossfading", true)
	MusicManager.set("_crossfade_from", from_player)
	MusicManager.set("_crossfade_to", to_player)
	MusicManager.set("_crossfade_target_db", -16.5)

func _cleanup_music_manager_state(from_player: AudioStreamPlayer, to_player: AudioStreamPlayer) -> void:
	MusicManager.set_ambient_music_suppressed(self, false, 0.0)
	MusicManager.clear_stack()
	MusicManager.stop_music(0.0)
	MusicManager.set("_is_crossfading", false)
	MusicManager.set("_crossfade_from", null)
	MusicManager.set("_crossfade_to", null)
	MusicManager.set("_crossfade_target_db", 0.0)
	if from_player != null:
		from_player.stop()
		from_player.stream = null
	if to_player != null:
		to_player.stop()
		to_player.stream = null

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
