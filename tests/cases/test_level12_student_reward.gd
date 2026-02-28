extends "res://tests/test_case.gd"

const MONEY_SYSTEM_SCENE_PATH := "res://objects/interactable/level12/money/level12_money_system.tscn"
const STUDENT_SCENE_PATH := "res://objects/interactable/level12/student/student_money_npc.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var root := Node.new()
	tree.root.add_child(root)

	var money_scene := assert_loads(MONEY_SYSTEM_SCENE_PATH) as PackedScene
	var student_scene := assert_loads(STUDENT_SCENE_PATH) as PackedScene
	assert_true(money_scene != null, "Money scene failed to load")
	assert_true(student_scene != null, "Student scene failed to load")
	if money_scene == null or student_scene == null:
		root.queue_free()
		await tree.process_frame
		return get_failures()

	var money_system := money_scene.instantiate()
	money_system.name = "Level12MoneySystem"
	root.add_child(money_system)

	var student := student_scene.instantiate()
	student.set("money_system_path", NodePath("../Level12MoneySystem"))
	student.set("fade_out_duration", 0.0)
	student.set("fade_in_duration", 0.0)
	student.set("reward_money", 40)
	root.add_child(student)
	await tree.process_frame

	await _await_if_needed(student.call("_on_interact"))
	assert_eq(int(money_system.call("get_money")), 40, "Student should grant money on first interaction")

	await _await_if_needed(student.call("_on_interact"))
	assert_eq(int(money_system.call("get_money")), 40, "Student reward must be one-time")

	root.queue_free()
	await tree.process_frame
	return get_failures()

func _await_if_needed(result: Variant) -> void:
	if result is Object and (result as Object).has_signal("completed"):
		await result
