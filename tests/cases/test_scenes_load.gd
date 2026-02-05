extends "res://tests/test_case.gd"

func run() -> Array[String]:
    var exclude_dirs: Array[String] = ["tests", ".godot", "addons"]
    var exclude_substrings: Array[String] = ["archive", "trash"]

    var scenes: Array[String] = []
    scenes.append_array(utils.list_files("res://levels", ".tscn", exclude_dirs, exclude_substrings))
    scenes.append_array(utils.list_files("res://player", ".tscn", exclude_dirs, exclude_substrings))
    scenes.append_array(utils.list_files("res://enemies", ".tscn", exclude_dirs, exclude_substrings))
    scenes.append_array(utils.list_files("res://objects", ".tscn", exclude_dirs, exclude_substrings))

    assert_true(scenes.size() > 0, "No scenes found for smoke loading")

    for path in scenes:
        var res = assert_loads(path)
        if res == null:
            continue
        if not (res is PackedScene):
            fail("Not a PackedScene: %s" % path)
            continue
        var instance = res.instantiate()
        if instance == null:
            fail("Failed to instantiate scene: %s" % path)
        else:
            instance.free()
    return get_failures()
