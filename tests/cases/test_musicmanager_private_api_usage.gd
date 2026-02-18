extends "res://tests/test_case.gd"

const SEARCH_DIRS := [
	"res://levels",
	"res://player",
	"res://enemies",
	"res://objects"
]
const ALLOWED_PRIVATE_ACCESS := {
	"res://levels/music_manager.gd": true
}

func run() -> Array[String]:
	var scripts: Array[String] = []
	for dir_path in SEARCH_DIRS:
		scripts.append_array(utils.list_files(dir_path, ".gd", ["tests", ".godot", "addons"]))
	scripts.sort()
	for path in scripts:
		if ALLOWED_PRIVATE_ACCESS.has(path):
			continue
		var content := FileAccess.get_file_as_string(path)
		assert_true(content != "", "Failed to read script: %s" % path)
		if content == "":
			continue
		assert_true(content.find("MusicManager._") == -1, "Private MusicManager API usage is forbidden: %s" % path)
	return get_failures()
