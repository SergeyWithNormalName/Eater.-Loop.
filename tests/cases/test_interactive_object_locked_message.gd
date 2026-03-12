extends "res://tests/test_case.gd"

const InteractiveObjectScript := preload("res://objects/interactable/interactive_object.gd")
const LOCKED_MESSAGE := "Тестовое сообщение блокировки"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var ui = tree.root.get_node_or_null("UIMessage")
	assert_true(ui != null, "UIMessage autoload is missing")
	if ui == null:
		return get_failures()

	var dependency = InteractiveObjectScript.new()
	var locked_object = InteractiveObjectScript.new()
	tree.root.add_child(dependency)
	tree.root.add_child(locked_object)
	await tree.process_frame

	locked_object.locked_message = LOCKED_MESSAGE
	locked_object.set_dependency_object(dependency)
	locked_object.request_interact()

	assert_true(ui.is_notification_visible(), "Blocked interaction must show a notification")
	assert_eq(ui.get_notification_text(), LOCKED_MESSAGE, "Blocked interaction must use locked_message by default")
	assert_true(not locked_object.is_completed, "Blocked interaction must not complete the object")

	dependency.complete_interaction()
	await tree.process_frame
	assert_true(bool(locked_object.call("_is_dependency_satisfied")), "Dependency setter must rebind completion listener and unlock interaction")

	locked_object.queue_free()
	dependency.queue_free()
	await tree.process_frame
	return get_failures()
