extends "res://tests/test_case.gd"

const SEARCH_DIRS := [
	"res://levels",
	"res://objects",
	"res://player",
	"res://enemies",
	"res://global"
]
const SCENE_DIRS := [
	"res://levels",
	"res://player",
	"res://enemies",
	"res://objects"
]
const ALLOWED_PRIVATE_INTERACTIVE_ACCESS := {
	"res://objects/interactable/interactive_object.gd": true
}
const INTERACTIVE_PRIVATE_PATTERNS := [
	"_setup_dependency_listener",
	"_refresh_prompt_state"
]
const LEGACY_UI_TEXT_PATTERNS := [
	"show_text(",
	"show_message(",
	"show_subtitle("
]
const LEGACY_INTERACTION_FLAG_PATTERNS := [
	".auto_prompt =",
	".handle_input ="
]
const LEGACY_SCENE_CALLBACK_PATTERNS := [
	"on_fed_andrey"
]
const GAME_DIRECTOR_PATH := "res://levels/game_director.gd"
const GAME_STATE_PATH := "res://levels/cycles/game_state.gd"
const FRIDGE_PATH := "res://objects/interactable/fridge/fridge.gd"
const ACTIVE_SCENE_EXCLUDE_SUBSTRINGS: Array[String] = ["archive", "trash"]
const FORBIDDEN_GAME_DIRECTOR_PATTERNS := [
	"has_method(\"handle_custom_death_screen\")",
	"call(\"handle_custom_death_screen\"",
	"call('handle_custom_death_screen'"
]
const FORBIDDEN_ACTIVE_SCENE_PATTERNS := [
	"archive(trash)"
]
const MIGRATED_TYPED_CONTRACT_PATHS := [
	"res://levels/cycles/game_state.gd",
	"res://levels/cycles/cycle_state.gd",
	"res://levels/cycles/crazy_level_event.gd",
	"res://levels/cycles/level_07_doors.gd",
	"res://levels/cycles/level_11_stu_1.gd",
	"res://levels/cycles/level_12_stu_2.gd",
	"res://levels/cycles/level_13_stu_3.gd",
	"res://objects/interactable/level12/blockpost/blockpost.gd",
	"res://objects/interactable/generator/generator.gd",
]
const FORBIDDEN_MIGRATED_STRINGLY_PATTERNS := [
	"has_method(",
	".call(",
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

		for pattern in LEGACY_UI_TEXT_PATTERNS:
			assert_true(content.find(pattern) == -1, "Legacy UI text API usage is forbidden: %s (%s)" % [path, pattern])

		for pattern in LEGACY_INTERACTION_FLAG_PATTERNS:
			assert_true(content.find(pattern) == -1, "Legacy interaction flag mutation is forbidden: %s (%s)" % [path, pattern])

		for pattern in LEGACY_SCENE_CALLBACK_PATTERNS:
			assert_true(content.find(pattern) == -1, "Legacy scene callback is forbidden: %s (%s)" % [path, pattern])

	var scenes: Array[String] = []
	for dir_path in SCENE_DIRS:
		scenes.append_array(utils.list_files(dir_path, ".tscn", ["tests", ".godot", "addons"], ACTIVE_SCENE_EXCLUDE_SUBSTRINGS))
	scenes.sort()
	for path in scenes:
		var content := FileAccess.get_file_as_string(path)
		assert_true(content != "", "Failed to read scene: %s" % path)
		if content == "":
			continue
		for pattern in FORBIDDEN_ACTIVE_SCENE_PATTERNS:
			assert_true(content.find(pattern) == -1, "Active scene must not reference archived resources: %s (%s)" % [path, pattern])

	var game_director_content := FileAccess.get_file_as_string(GAME_DIRECTOR_PATH)
	assert_true(game_director_content != "", "Failed to read script: %s" % GAME_DIRECTOR_PATH)
	if game_director_content != "":
		for pattern in FORBIDDEN_GAME_DIRECTOR_PATTERNS:
			assert_true(game_director_content.find(pattern) == -1, "Stringly custom death handler access is forbidden: %s" % pattern)

	var game_state_content := FileAccess.get_file_as_string(GAME_STATE_PATH)
	assert_true(game_state_content.find("func autosave_run") != -1, "GameState must expose public autosave_run()")

	var fridge_content := FileAccess.get_file_as_string(FRIDGE_PATH)
	assert_true(fridge_content.find("autosave_run") != -1, "Fridge must trigger autosave after successful interaction")

	for path in MIGRATED_TYPED_CONTRACT_PATHS:
		var migrated_content := FileAccess.get_file_as_string(path)
		assert_true(migrated_content != "", "Failed to read migrated script: %s" % path)
		if migrated_content == "":
			continue
		for pattern in FORBIDDEN_MIGRATED_STRINGLY_PATTERNS:
			assert_true(migrated_content.find(pattern) == -1, "Migrated script must not use stringly dispatch: %s (%s)" % [path, pattern])

	return get_failures()
