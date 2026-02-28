extends "res://tests/test_case.gd"

const GENERATOR_SCENE_PATH := "res://objects/interactable/generator/generator.tscn"
const LAMP_SCENE_PATH := "res://objects/interactable/lamp/lamp.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var root := Node.new()
	tree.root.add_child(root)

	var lamp_scene := assert_loads(LAMP_SCENE_PATH) as PackedScene
	var generator_scene := assert_loads(GENERATOR_SCENE_PATH) as PackedScene
	assert_true(lamp_scene != null, "Lamp scene failed to load")
	assert_true(generator_scene != null, "Generator scene failed to load")
	if lamp_scene == null or generator_scene == null:
		root.queue_free()
		await tree.process_frame
		return get_failures()

	var required_lamp := lamp_scene.instantiate()
	required_lamp.set("requires_generator", true)
	root.add_child(required_lamp)

	var regular_lamp := lamp_scene.instantiate()
	root.add_child(regular_lamp)

	var generator := generator_scene.instantiate()
	generator.set("linked_lights", [])
	root.add_child(generator)
	await tree.process_frame

	assert_true(not _is_lit(required_lamp), "Required lamp must start off")
	assert_true(not _is_lit(regular_lamp), "Regular lamp must start off")

	generator.call("_on_interact")
	assert_true(_is_lit(required_lamp), "Generator should activate all lamps with requires_generator")
	assert_true(not _is_lit(regular_lamp), "Generator should not force regular lamps on when not linked")

	root.queue_free()
	await tree.process_frame
	return get_failures()

func _is_lit(lamp: Node) -> bool:
	var light := lamp.get_node_or_null("PointLight2D") as PointLight2D
	return light != null and light.enabled
