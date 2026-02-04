extends "res://tests/test_case.gd"

func run() -> Array[String]:
    var cfg = utils.load_project_config()
    if cfg == null:
        fail("Failed to load project.godot")
        return get_failures()

    var main_scene = cfg.get_value("application", "run/main_scene", "")
    assert_true(main_scene != "", "application/run/main_scene is empty")
    if main_scene != "":
        var res = assert_loads(main_scene)
        if res != null and not (res is PackedScene):
            fail("Main scene is not a PackedScene: %s" % main_scene)
    return get_failures()
