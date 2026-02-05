extends "res://tests/test_case.gd"

func run() -> Array[String]:
    var cfg = utils.load_project_config()
    if cfg == null:
        fail("Failed to load project.godot")
        return get_failures()

    var keys = cfg.get_section_keys("autoload")
    assert_true(keys.size() > 0, "No autoloads configured")

    for name in keys:
        var value = cfg.get_value("autoload", name, "")
        if typeof(value) != TYPE_STRING:
            fail("Autoload %s has non-string value" % name)
            continue
        var path = String(value)
        if path.begins_with("*"):
            path = path.substr(1)
        assert_true(path != "", "Autoload %s has empty path" % name)
        if path == "":
            continue
        var res = assert_loads(path)
        if res == null:
            continue
        if res is PackedScene:
            var instance = res.instantiate()
            if instance == null:
                fail("Failed to instantiate autoload scene: %s" % path)
            else:
                instance.free()
    return get_failures()
