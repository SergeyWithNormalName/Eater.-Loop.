extends "res://tests/test_case.gd"

func run() -> Array[String]:
    var cfg = utils.load_project_config()
    if cfg == null:
        fail("Failed to load project.godot")
        return get_failures()

    var actions = cfg.get_section_keys("input")
    assert_true(actions.size() > 0, "No input actions defined")

    var required = [
        "move_left",
        "move_right",
        "interact",
        "run",
        "pause_menu",
        "mg_cancel",
        "mg_grab",
        "mg_confirm",
        "mg_secondary",
        "mg_nav_left",
        "mg_nav_right",
        "mg_nav_up",
        "mg_nav_down",
        "mg_tab_left",
        "mg_tab_right",
        "ui_accept",
        "ui_cancel",
        "ui_left",
        "ui_right",
        "ui_up",
        "ui_down"
    ]
    for name in required:
        assert_true(InputMap.has_action(name), "Missing input action: %s" % name)
        if InputMap.has_action(name):
            var events = InputMap.action_get_events(name)
            assert_true(events.size() > 0, "Input action has no events: %s" % name)
    return get_failures()
