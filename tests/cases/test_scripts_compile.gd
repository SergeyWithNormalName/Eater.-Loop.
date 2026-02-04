extends "res://tests/test_case.gd"

func run() -> Array[String]:
    var exclude_dirs: Array[String] = ["tests", ".godot", "addons"]
    var scripts = utils.list_files("res://", ".gd", exclude_dirs)

    assert_true(scripts.size() > 0, "No scripts found for compile check")

    for path in scripts:
        var res = assert_loads(path)
        if res == null:
            continue
        if not (res is GDScript):
            fail("Not a GDScript resource: %s" % path)
    return get_failures()
