extends "res://tests/test_case.gd"

func run() -> Array[String]:
	var scripts_with_scheme := [
		"res://levels/minigames/labs/sql/sql_minigame.gd",
		"res://levels/minigames/labs/LLM/llm_minigame.gd",
		"res://levels/minigames/feeding/feed_minigame.gd",
		"res://levels/minigames/search_key/search_minigame.gd",
		"res://objects/interactable/fridge/code_lock.gd"
	]
	for path in scripts_with_scheme:
		_assert_script_contains(path, "set_gamepad_scheme", "Missing gamepad scheme registration")
		_assert_script_contains(path, "clear_gamepad_scheme", "Missing gamepad scheme cleanup")

	_assert_script_contains("res://levels/minigames/minigame_controller.gd", "func set_gamepad_scheme", "MinigameController API set_gamepad_scheme missing")
	_assert_script_contains("res://levels/minigames/minigame_controller.gd", "func clear_gamepad_scheme", "MinigameController API clear_gamepad_scheme missing")
	_assert_script_not_contains("res://levels/minigames/minigame_controller.gd", "warp_mouse", "Legacy warp_mouse call must be removed")
	return get_failures()

func _assert_script_contains(path: String, needle: String, message: String) -> void:
	if not FileAccess.file_exists(path):
		fail("Missing file: %s" % path)
		return
	var content := FileAccess.get_file_as_string(path)
	assert_true(content.find(needle) != -1, "%s (%s)" % [message, path])

func _assert_script_not_contains(path: String, needle: String, message: String) -> void:
	if not FileAccess.file_exists(path):
		fail("Missing file: %s" % path)
		return
	var content := FileAccess.get_file_as_string(path)
	assert_true(content.find(needle) == -1, "%s (%s)" % [message, path])
