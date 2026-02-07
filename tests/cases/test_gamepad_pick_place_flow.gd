extends "res://tests/test_case.gd"

const GamepadRuntime = preload("res://levels/minigames/gamepad/gamepad_runtime.gd")

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		fail("SceneTree is not available")
		return get_failures()

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(host)

	var source_a := Button.new()
	source_a.position = Vector2(120, 180)
	source_a.size = Vector2(100, 50)
	host.add_child(source_a)

	var source_b := Button.new()
	source_b.position = Vector2(280, 180)
	source_b.size = Vector2(100, 50)
	host.add_child(source_b)

	var target := Panel.new()
	target.position = Vector2(200, 320)
	target.size = Vector2(120, 56)
	host.add_child(target)

	var state := {
		"place_calls": 0,
		"secondary_calls": 0,
		"last_source": null,
		"last_target": null
	}

	var runtime = GamepadRuntime.new()
	runtime.start(host, {
		"mode": "pick_place",
		"source_nodes": [source_a, source_b],
		"target_nodes": [target],
		"on_place": func(source: Node, destination: Node, _context: Dictionary) -> bool:
			state["place_calls"] += 1
			state["last_source"] = source
			state["last_target"] = destination
			return true,
		"on_secondary": func(_active: Node, _context: Dictionary) -> bool:
			state["secondary_calls"] += 1
			return true
	})

	assert_true(runtime.handle_input(_action("mg_confirm")), "Initial confirm should be handled")
	assert_true(runtime.handle_cancel(), "Cancel should reset selected source in pick_place mode")
	assert_true(runtime.handle_input(_action("mg_confirm")), "Second confirm should select source")
	assert_true(runtime.handle_input(_action("mg_tab_left")), "Tab should return focus to source section")
	assert_true(runtime.handle_input(_action("mg_nav_right")), "Navigation should move source selection to the right")
	assert_true(runtime.handle_input(_action("mg_confirm")), "Third confirm should switch selected source")
	assert_true(runtime.handle_input(_action("mg_confirm")), "Fourth confirm should place source into target")

	assert_eq(state["place_calls"], 1, "on_place callback was not called once")
	assert_eq(state["last_source"], source_b, "Selected source mismatch after switching selection")
	assert_eq(state["last_target"], target, "Selected target mismatch")

	assert_true(runtime.handle_input(_action("mg_secondary")), "Secondary action should be handled")
	assert_eq(state["secondary_calls"], 1, "Secondary callback should run once")

	runtime.clear()
	host.queue_free()
	return get_failures()

func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event
