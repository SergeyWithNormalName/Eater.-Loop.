extends "res://tests/test_case.gd"

const MONEY_SYSTEM_SCENE_PATH := "res://objects/interactable/level12/money/level12_money_system.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var root := Node.new()
	tree.root.add_child(root)

	var scene := assert_loads(MONEY_SYSTEM_SCENE_PATH) as PackedScene
	assert_true(scene != null, "Money system scene failed to load")
	if scene == null:
		root.queue_free()
		await tree.process_frame
		return get_failures()

	var money_system := scene.instantiate()
	root.add_child(money_system)
	await tree.process_frame

	assert_eq(int(money_system.call("get_money")), 0, "Money should start from 0")
	assert_true(not bool(money_system.call("has_enough_money", 100)), "0 money should not pass blockpost")

	money_system.call("add_money", 40, "NPC")
	assert_eq(int(money_system.call("get_money")), 40, "After NPC reward money should be 40")
	assert_true(not bool(money_system.call("try_open_blockpost", 100)), "40 money should not pass blockpost")

	money_system.call("add_money", 60, "Lab")
	assert_eq(int(money_system.call("get_money")), 100, "After lab reward money should be 100")
	assert_true(bool(money_system.call("try_open_blockpost", 100)), "100 money should pass blockpost")

	var hud_visible := _is_any_label_visible(money_system)
	assert_true(hud_visible, "Money HUD label should become visible after updates")

	root.queue_free()
	await tree.process_frame
	return get_failures()

func _is_any_label_visible(node: Node) -> bool:
	if node is Label and (node as Label).visible:
		return true
	for child in node.get_children():
		if child is Node and _is_any_label_visible(child):
			return true
	return false
