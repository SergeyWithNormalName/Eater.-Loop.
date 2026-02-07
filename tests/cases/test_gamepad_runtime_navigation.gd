extends "res://tests/test_case.gd"

const GamepadSpatialNav = preload("res://levels/minigames/gamepad/gamepad_spatial_nav.gd")

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		fail("SceneTree is not available")
		return get_failures()

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(host)

	var center := Button.new()
	center.position = Vector2(200, 200)
	center.size = Vector2(80, 40)
	host.add_child(center)

	var right := Button.new()
	right.position = Vector2(340, 200)
	right.size = Vector2(80, 40)
	host.add_child(right)

	var down := Button.new()
	down.position = Vector2(200, 320)
	down.size = Vector2(80, 40)
	host.add_child(down)

	var nav = GamepadSpatialNav.new()
	assert_eq(nav.find_next(center, [center, right, down], Vector2.RIGHT), right, "RIGHT navigation failed")
	assert_eq(nav.find_next(center, [center, right, down], Vector2.DOWN), down, "DOWN navigation failed")
	assert_eq(nav.find_next(center, [center, right, down], Vector2.LEFT), right, "Wrap LEFT navigation failed")

	host.queue_free()
	return get_failures()
