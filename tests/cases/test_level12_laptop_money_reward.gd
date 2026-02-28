extends "res://tests/test_case.gd"

const MONEY_SYSTEM_SCENE_PATH := "res://objects/interactable/level12/money/level12_money_system.tscn"
const LAPTOP_SCENE_PATH := "res://objects/interactable/level12/notebook/laptop_money.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	if GameState and GameState.has_method("reset_run"):
		GameState.reset_run()

	var root := Node.new()
	tree.root.add_child(root)

	var money_scene := assert_loads(MONEY_SYSTEM_SCENE_PATH) as PackedScene
	var laptop_scene := assert_loads(LAPTOP_SCENE_PATH) as PackedScene
	assert_true(money_scene != null, "Money scene failed to load")
	assert_true(laptop_scene != null, "Laptop scene failed to load")
	if money_scene == null or laptop_scene == null:
		root.queue_free()
		await tree.process_frame
		return get_failures()

	var money_system := money_scene.instantiate()
	money_system.name = "Level12MoneySystem"
	root.add_child(money_system)

	var laptop := laptop_scene.instantiate()
	laptop.set("money_system_path", NodePath("../Level12MoneySystem"))
	laptop.set("reward_money", 60)
	root.add_child(laptop)
	await tree.process_frame

	laptop.set("_lab_completed_before_minigame", false)
	if GameState and GameState.has_method("mark_lab_completed"):
		GameState.mark_lab_completed()

	laptop.call("_on_minigame_closed")
	assert_eq(int(money_system.call("get_money")), 60, "Laptop should reward money after lab completion")

	laptop.call("_on_minigame_closed")
	assert_eq(int(money_system.call("get_money")), 60, "Laptop reward must be one-time")

	root.queue_free()
	await tree.process_frame

	if GameState and GameState.has_method("reset_run"):
		GameState.reset_run()
	return get_failures()
