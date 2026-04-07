extends "res://tests/test_case.gd"

const PROJECTOR_SCENE_PATH := "res://objects/interactable/projector/projector.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var projector_scene := assert_loads(PROJECTOR_SCENE_PATH) as PackedScene
	assert_true(projector_scene != null, "Projector scene failed to load")
	if projector_scene == null:
		return get_failures()

	var root := Node2D.new()
	tree.root.add_child(root)

	var projector := projector_scene.instantiate()
	root.add_child(projector)
	await tree.process_frame

	var beam_visual := projector.get_node_or_null("BeamVisual") as Polygon2D
	var beam_core := projector.get_node_or_null("BeamCore") as Polygon2D
	var point_light := projector.get_node_or_null("PointLight2D") as PointLight2D
	assert_true(beam_visual != null, "Projector must expose BeamVisual polygon")
	assert_true(beam_core != null, "Projector must expose BeamCore polygon")
	assert_true(point_light != null, "Projector must expose PointLight2D")
	if beam_visual == null or beam_core == null or point_light == null:
		root.queue_free()
		await tree.process_frame
		return get_failures()

	assert_true(not point_light.enabled, "Projector light must start disabled by default")
	assert_true(not beam_visual.visible, "Projector beam visual must start hidden when light is off")
	assert_true(not beam_core.visible, "Projector beam core must start hidden when light is off")

	projector.request_interact()
	await tree.process_frame
	assert_true(point_light.enabled, "Projector light must enable after interaction")
	assert_true(beam_visual.visible, "Projector beam visual must enable after interaction")
	assert_true(beam_core.visible, "Projector beam core must enable after interaction")

	projector.request_interact()
	await tree.process_frame
	assert_true(not point_light.enabled, "Projector light must disable on second interaction")
	assert_true(not beam_visual.visible, "Projector beam visual must disable on second interaction")
	assert_true(not beam_core.visible, "Projector beam core must disable on second interaction")

	root.queue_free()
	await tree.process_frame
	return get_failures()
