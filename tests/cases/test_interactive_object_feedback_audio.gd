extends "res://tests/test_case.gd"

const InteractiveObjectScript = preload("res://objects/interactable/interactive_object.gd")
const TEST_AUDIO_PATH := "res://music/MyHorrorHit_3.wav"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var root := Node.new()
	tree.root.add_child(root)

	var interactable := InteractiveObjectScript.new()
	root.add_child(interactable)
	await tree.process_frame

	var audio_player := _find_audio_player(interactable)
	assert_true(audio_player != null, "InteractiveObject must provision a shared feedback audio player")

	var stream := assert_loads(TEST_AUDIO_PATH) as AudioStream
	assert_true(stream != null, "Test audio stream failed to load")
	if audio_player != null and stream != null:
		interactable.play_feedback_sfx(stream, -4.0, 1.0, 1.0)
		assert_true(audio_player.stream == stream, "play_feedback_sfx() must route the requested stream to the shared player")
		assert_true(audio_player.playing, "play_feedback_sfx() must start playback immediately")

	interactable.set_interaction_enabled(false)
	assert_true(not interactable.handle_input, "set_interaction_enabled(false) must disable input handling")
	interactable.set_interaction_enabled(true)
	assert_true(interactable.handle_input, "set_interaction_enabled(true) must restore input handling")

	root.queue_free()
	await tree.process_frame
	return get_failures()

func _find_audio_player(node: Node) -> AudioStreamPlayer2D:
	for child in node.get_children():
		if child is AudioStreamPlayer2D:
			return child as AudioStreamPlayer2D
	return null
