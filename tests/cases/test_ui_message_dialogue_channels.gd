extends "res://tests/test_case.gd"

const NOTIFICATION_TEXT := "Системное уведомление"
const DIALOGUE_TEXT := "Тихая реплика"
const QUEUED_DIALOGUE_TEXT := "Отложенная реплика"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var ui = tree.root.get_node_or_null("UIMessage")
	assert_true(ui != null, "UIMessage autoload is missing")
	if ui == null:
		return get_failures()

	ui.hide_subtitle()

	ui.show_notification(NOTIFICATION_TEXT, 0.1)
	assert_true(ui.is_notification_visible(), "Notification channel must become visible")
	assert_eq(ui.get_notification_text(), NOTIFICATION_TEXT, "Notification channel must show its own text")
	await tree.create_timer(0.2, true).timeout
	assert_true(not ui.is_notification_visible(), "Notification channel must auto-hide after timeout")

	ui.show_dialogue(DIALOGUE_TEXT, null, 0.1)
	assert_true(ui.is_dialogue_visible(), "Dialogue channel must become visible")
	assert_eq(ui.get_dialogue_text(), DIALOGUE_TEXT, "Dialogue channel must show its own text")
	assert_true(not ui.is_dialogue_voice_playing(), "Dialogue without voice must stay silent")
	await tree.create_timer(0.2, true).timeout
	assert_true(not ui.is_dialogue_visible(), "Dialogue channel must auto-hide after timeout")

	var note_transition_duration := float(ui.get("note_transition_duration"))
	var note_transition_wait := maxf(0.1, note_transition_duration * 2.0 + 0.1)
	var was_paused := tree.paused
	ui.show_note(_build_test_texture())
	assert_true(tree.paused, "Reading a note must pause the tree")
	ui.show_dialogue(QUEUED_DIALOGUE_TEXT, null, 1.0)
	assert_true(not ui.is_dialogue_visible(), "Dialogue must queue while note viewer is open")
	await tree.create_timer(note_transition_wait, true).timeout
	ui.hide_note()
	await tree.create_timer(note_transition_wait, true).timeout
	assert_eq(tree.paused, was_paused, "Closing a note must restore previous pause state")
	assert_true(ui.is_dialogue_visible(), "Queued dialogue must flush after closing note viewer")
	assert_eq(ui.get_dialogue_text(), QUEUED_DIALOGUE_TEXT, "Queued dialogue text must survive note viewer")
	await tree.create_timer(0.2, true).timeout
	ui.hide_subtitle()

	return get_failures()

func _build_test_texture() -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
