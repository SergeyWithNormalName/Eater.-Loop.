extends "res://tests/test_case.gd"

const BEDROOM_SCENES := [
	"res://levels/cycles/level_01_start.tscn",
	"res://levels/cycles/level_02_basic.tscn",
	"res://levels/cycles/level_03_deepseek.tscn",
	"res://levels/cycles/level_04_findkey.tscn",
	"res://levels/cycles/level_05_sql.tscn",
	"res://levels/cycles/level_06_corridordistortion.tscn",
	"res://levels/cycles/level_07_doors.tscn",
	"res://levels/cycles/level_08_PT.tscn",
	"res://levels/cycles/level_NSTU_test.tscn"
]

func run() -> Array[String]:
	_assert_trigger_script_supports_ambient_actions()
	for scene_path in BEDROOM_SCENES:
		_assert_scene_uses_ambient_suppression(scene_path)
	return get_failures()

func _assert_trigger_script_supports_ambient_actions() -> void:
	var script_text := FileAccess.get_file_as_string("res://objects/interactable/trigger/trigger_set_property.gd")
	assert_true(script_text != "", "Failed to read trigger_set_property.gd")
	assert_true(script_text.find("MUSIC_ACTION_SUPPRESS_AMBIENT := 8") != -1, "Missing suppress ambient action constant")
	assert_true(script_text.find("MUSIC_ACTION_RESTORE_AMBIENT := 9") != -1, "Missing restore ambient action constant")
	assert_true(script_text.find("set_ambient_music_suppressed(self, true") != -1, "Trigger enter action must call MusicManager.set_ambient_music_suppressed(..., true, ...)")
	assert_true(script_text.find("set_ambient_music_suppressed(self, false") != -1, "Trigger exit action must call MusicManager.set_ambient_music_suppressed(..., false, ...)")

func _assert_scene_uses_ambient_suppression(scene_path: String) -> void:
	var text := FileAccess.get_file_as_string(scene_path)
	assert_true(text != "", "Failed to read scene: %s" % scene_path)
	if text == "":
		return

	var lines := text.split("\n")
	var trigger_count := 0
	for i in range(lines.size()):
		var line := lines[i]
		if line.find("[node name=\"TriggerBedroomSilent") == -1:
			continue
		trigger_count += 1
		var block := _collect_node_block(lines, i)
		assert_true(block.find("music_on_enter = 8") != -1, "%s: bedroom trigger must set music_on_enter = 8" % scene_path)
		assert_true(block.find("music_on_exit = 9") != -1, "%s: bedroom trigger must set music_on_exit = 9" % scene_path)
		assert_true(block.find("music_on_enter = 6") == -1, "%s: bedroom trigger must not use pause-all enter action (6)" % scene_path)
		assert_true(block.find("music_on_exit = 7") == -1, "%s: bedroom trigger must not use resume-all exit action (7)" % scene_path)

	assert_true(trigger_count > 0, "%s: no TriggerBedroomSilent nodes found" % scene_path)

func _collect_node_block(lines: PackedStringArray, start_index: int) -> String:
	var end_index := lines.size()
	for i in range(start_index + 1, lines.size()):
		if lines[i].begins_with("[node "):
			end_index = i
			break
	return "\n".join(lines.slice(start_index, end_index))
