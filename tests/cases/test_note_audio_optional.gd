extends "res://tests/test_case.gd"

const NOTE_SCENE_PATH := "res://objects/interactable/note/note.tscn"
const TEST_AUDIO_PATH := "res://music/MyHorrorHit_3.wav"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var root := Node.new()
	tree.root.add_child(root)

	var note_scene := assert_loads(NOTE_SCENE_PATH) as PackedScene
	assert_true(note_scene != null, "Note scene failed to load")
	if note_scene == null:
		root.queue_free()
		await tree.process_frame
		return get_failures()

	var note := note_scene.instantiate()
	note.set("note_texture", null)
	note.set("read_audio", null)
	root.add_child(note)
	await tree.process_frame

	var audio_player := _find_audio_player(note)
	assert_true(audio_player != null, "Note must create a local audio player")
	if audio_player == null:
		root.queue_free()
		await tree.process_frame
		return get_failures()

	note.call("_on_interact")
	assert_true(not audio_player.playing, "Note should stay silent if read_audio is not assigned")

	var stream := assert_loads(TEST_AUDIO_PATH) as AudioStream
	assert_true(stream != null, "Test audio stream failed to load")
	if stream != null:
		note.set("read_audio", stream)
		note.call("_on_interact")
		assert_true(audio_player.playing, "Note should play audio if read_audio is assigned")

	root.queue_free()
	await tree.process_frame
	return get_failures()

func _find_audio_player(node: Node) -> AudioStreamPlayer2D:
	for child in node.get_children():
		if child is AudioStreamPlayer2D:
			return child as AudioStreamPlayer2D
	return null
