extends "res://tests/test_case.gd"

const LEVELS_DIR := "res://levels/cycles"
const SEARCH_DIRS := [
	"res://levels",
	"res://player",
	"res://enemies",
	"res://objects"
]
const LEVEL_MUSIC_SCRIPT_PATH := "res://levels/cycles/level_music.gd"

func run() -> Array[String]:
	_assert_level_music_nodes_use_level_music_script()
	_assert_runtime_audio_players_assign_a_bus()
	return get_failures()

func _assert_level_music_nodes_use_level_music_script() -> void:
	var scene_paths := utils.list_files(LEVELS_DIR, ".tscn", ["tests", ".godot", "addons"])
	for scene_path in scene_paths:
		var text := FileAccess.get_file_as_string(scene_path)
		assert_true(text != "", "Failed to read scene: %s" % scene_path)
		if text == "":
			continue
		if text.find("[node name=\"Music\" type=\"AudioStreamPlayer\"") == -1:
			continue
		var ext_resources := _parse_ext_resource_paths(text.split("\n"))
		var music_blocks := _collect_node_blocks(text.split("\n"), "[node name=\"Music\" type=\"AudioStreamPlayer\"")
		assert_true(not music_blocks.is_empty(), "%s: expected at least one Music node block" % scene_path)
		for block in music_blocks:
			var ext_id := _extract_ext_resource_id(block, "script = ExtResource(\"")
			assert_true(ext_id != "", "%s: Music node must declare a LevelMusic script" % scene_path)
			if ext_id == "":
				continue
			assert_eq(String(ext_resources.get(ext_id, "")), LEVEL_MUSIC_SCRIPT_PATH, "%s: Music node must use levels/cycles/level_music.gd" % scene_path)

func _assert_runtime_audio_players_assign_a_bus() -> void:
	var script_paths: Array[String] = []
	for dir_path in SEARCH_DIRS:
		script_paths.append_array(utils.list_files(dir_path, ".gd", ["tests", ".godot", "addons"]))
	script_paths.sort()
	for script_path in script_paths:
		var content := FileAccess.get_file_as_string(script_path)
		assert_true(content != "", "Failed to read script: %s" % script_path)
		if content == "":
			continue
		if not _creates_runtime_audio_player(content):
			continue
		var has_bus_assignment := content.find(".bus =") != -1 or content.find("_setup_player(") != -1 or content.find("audio_bus") != -1
		assert_true(has_bus_assignment, "%s: runtime-created AudioStreamPlayers must assign a bus explicitly" % script_path)

func _parse_ext_resource_paths(lines: PackedStringArray) -> Dictionary:
	var result := {}
	for line in lines:
		if not line.begins_with("[ext_resource"):
			continue
		var id := _extract_quoted_value_after(line, " id=")
		var path := _extract_quoted_value_after(line, "path=")
		if id == "" or path == "":
			continue
		result[id] = path
	return result

func _collect_node_blocks(lines: PackedStringArray, prefix: String) -> Array[String]:
	var blocks: Array[String] = []
	for i in range(lines.size()):
		if not lines[i].begins_with(prefix):
			continue
		var end_index := lines.size()
		for j in range(i + 1, lines.size()):
			if lines[j].begins_with("[node "):
				end_index = j
				break
		blocks.append("\n".join(lines.slice(i, end_index)))
	return blocks

func _extract_ext_resource_id(block: String, prefix: String) -> String:
	return _extract_quoted_value_after(block, prefix)

func _extract_quoted_value_after(text: String, marker: String) -> String:
	var start := text.find(marker)
	if start == -1:
		return ""
	var value_start := start + marker.length()
	if value_start >= text.length():
		return ""
	if text.substr(value_start, 1) == "\"":
		value_start += 1
	var quote_end := text.find("\"", value_start)
	if quote_end == -1:
		return ""
	return text.substr(value_start, quote_end - value_start)

func _creates_runtime_audio_player(content: String) -> bool:
	return content.find("AudioStreamPlayer.new()") != -1 \
		or content.find("AudioStreamPlayer2D.new()") != -1 \
		or content.find("AudioStreamPlayer3D.new()") != -1
