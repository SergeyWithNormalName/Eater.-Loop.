extends Control
class_name TimedLabMinigameBase

@warning_ignore("unused_signal")
signal task_completed(success: bool)

@export_group("Timed Lab")
@export var time_limit: float = 60.0
@export var penalty_time: float = 15.0
@export var lab_completion_id: String = ""
@export var complete_lab_on_failure: bool = true
@export_multiline var success_dialogue_text: String = ""
@export_multiline var failure_dialogue_text: String = ""
@export var success_dialogue_voice: AudioStream
@export var failure_dialogue_voice: AudioStream
@export var dialogue_duration: float = -1.0

const LAB_MUSIC_STREAM := preload("res://music/MusicForLabs.wav")

var current_time: float = 0.0

func start_timed_lab_session(
	on_time_updated: Callable,
	on_time_expired: Callable,
	music_stream: AudioStream = LAB_MUSIC_STREAM,
	music_fade_time: float = 0.0
) -> void:
	add_to_group("minigame_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_lab_music_loop(music_stream)
	var controller_active := MinigameController != null and MinigameController.is_active(self)
	if MinigameController != null and not controller_active:
		var settings := MinigameSettings.new()
		settings.pause_game = false
		settings.show_mouse_cursor = true
		settings.block_player_movement = true
		settings.time_limit = time_limit
		settings.music_stream = music_stream
		settings.music_fade_time = music_fade_time
		settings.auto_finish_on_timeout = false
		MinigameController.start_minigame(self, settings)
	elif controller_active and music_stream != null:
		MinigameController.update_minigame_music(music_stream, 999.0, music_fade_time)
	current_time = time_limit
	if MinigameController == null:
		return
	if on_time_updated.is_valid() and not MinigameController.minigame_time_updated.is_connected(on_time_updated):
		MinigameController.minigame_time_updated.connect(on_time_updated)
	if on_time_expired.is_valid() and not MinigameController.minigame_time_expired.is_connected(on_time_expired):
		MinigameController.minigame_time_expired.connect(on_time_expired)

func cleanup_timed_lab(on_time_updated: Callable, on_time_expired: Callable) -> void:
	if MinigameController == null:
		return
	MinigameController.clear_gamepad_scheme(self)
	if on_time_updated.is_valid() and MinigameController.minigame_time_updated.is_connected(on_time_updated):
		MinigameController.minigame_time_updated.disconnect(on_time_updated)
	if on_time_expired.is_valid() and MinigameController.minigame_time_expired.is_connected(on_time_expired):
		MinigameController.minigame_time_expired.disconnect(on_time_expired)
	if MinigameController.is_active(self):
		MinigameController.finish_minigame(self, false)

func apply_standard_lab_outcome(success: bool) -> void:
	if not success:
		var gd := get_node_or_null("/root/GameDirector")
		if gd != null:
			gd.reduce_time(penalty_time)
	if success or complete_lab_on_failure:
		var cycle_state := get_node_or_null("/root/CycleState")
		if cycle_state != null and cycle_state.has_method("mark_lab_completed"):
			cycle_state.mark_lab_completed(lab_completion_id.strip_edges())
	_show_outcome_dialogue(success)

func _show_outcome_dialogue(success: bool) -> void:
	if UIMessage == null or not UIMessage.has_method("show_dialogue"):
		return
	var text := success_dialogue_text if success else failure_dialogue_text
	var voice := success_dialogue_voice if success else failure_dialogue_voice
	if text.strip_edges() == "":
		return
	UIMessage.show_dialogue(text, voice, dialogue_duration)

func _ensure_lab_music_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return
	if stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = true
		return
	if stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		mp3.loop = true
