extends "res://tests/test_case.gd"

const SEARCH_DIRS := [
	"res://levels",
	"res://objects"
]
const ALLOWED_PRIVATE_INTERACTIVE_ACCESS := {
	"res://objects/interactable/interactive_object.gd": true
}
const INTERACTIVE_PRIVATE_PATTERNS := [
	"_setup_dependency_listener",
	"_refresh_prompt_state"
]
const LEGACY_SCENE_CALLBACK_PATTERNS := [
	"on_fed_andrey"
]
const GAME_DIRECTOR_PATH := "res://levels/game_director.gd"
const GAME_STATE_PATH := "res://levels/cycles/game_state.gd"
const FRIDGE_PATH := "res://objects/interactable/fridge/fridge.gd"
const FORBIDDEN_GAME_DIRECTOR_PATTERNS := [
	"has_method(\"handle_custom_death_screen\")",
	"call(\"handle_custom_death_screen\"",
	"call('handle_custom_death_screen'"
]

func run() -> Array[String]:
	var scripts: Array[String] = []
	for dir_path in SEARCH_DIRS:
		scripts.append_array(utils.list_files(dir_path, ".gd", ["tests", ".godot", "addons"]))
	scripts.sort()

	for path in scripts:
		var content := FileAccess.get_file_as_string(path)
		assert_true(content != "", "Failed to read script: %s" % path)
		if content == "":
			continue

		if not ALLOWED_PRIVATE_INTERACTIVE_ACCESS.has(path):
			for pattern in INTERACTIVE_PRIVATE_PATTERNS:
				assert_true(content.find(pattern) == -1, "InteractiveObject private API usage is forbidden: %s (%s)" % [path, pattern])

		for pattern in LEGACY_SCENE_CALLBACK_PATTERNS:
			assert_true(content.find(pattern) == -1, "Legacy scene callback is forbidden: %s (%s)" % [path, pattern])

	var game_director_content := FileAccess.get_file_as_string(GAME_DIRECTOR_PATH)
	assert_true(game_director_content != "", "Failed to read script: %s" % GAME_DIRECTOR_PATH)
	if game_director_content != "":
		for pattern in FORBIDDEN_GAME_DIRECTOR_PATTERNS:
			assert_true(game_director_content.find(pattern) == -1, "Stringly custom death handler access is forbidden: %s" % pattern)

	var game_state_content := FileAccess.get_file_as_string(GAME_STATE_PATH)
	assert_true(game_state_content.find("func autosave_run") != -1, "GameState must expose public autosave_run()")

	var fridge_content := FileAccess.get_file_as_string(FRIDGE_PATH)
	assert_true(fridge_content.find("autosave_run") != -1, "Fridge must trigger autosave after successful interaction")

	return get_failures()
