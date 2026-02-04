extends "res://tests/test_case.gd"

func run() -> Array[String]:
    var cfg = utils.load_project_config()
    if cfg == null:
        fail("Failed to load project.godot")
        return get_failures()

    var actions = cfg.get_section_keys("input")
    assert_true(actions.size() > 0, "No input actions defined")

    var required = ["move_left", "move_right", "interact", "run"]
    for name in required:
        assert_true(InputMap.has_action(name), "Missing input action: %s" % name)
        if InputMap.has_action(name):
            var events = InputMap.action_get_events(name)
            assert_true(events.size() > 0, "Input action has no events: %s" % name)
    return get_failures()
