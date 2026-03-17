extends "res://tests/test_case.gd"

const GameDirectorScript = preload("res://levels/game_director.gd")
class CustomDeathLevel:
	extends "res://levels/cycles/level.gd"

	var handled: bool = false

	func handle_custom_death_screen() -> bool:
		handled = true
		return true

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var root := Node.new()
	tree.root.add_child(root)

	var director := GameDirectorScript.new()
	root.add_child(director)
	await tree.process_frame

	director.set("_in_game_scene", true)
	director.start_normal_phase(0.05)
	await tree.create_timer(0.08, true).timeout
	assert_true(bool(director.get("_distortion_active")), "Timer expiry must activate the distortion phase")

	director.start_normal_phase(1.0)
	director.set("_distortion_active", false)
	director.set("_pending_distortion_activation", false)
	director.set("_minigame_active", true)
	director.set("_minigame_blocks_distortion", true)
	director.call("_on_distortion_timeout")
	assert_true(bool(director.get("_pending_distortion_activation")), "Blocking minigames must defer distortion activation")
	assert_true(not bool(director.get("_distortion_active")), "Deferred distortion must not activate immediately")

	director.call("_on_minigame_finished", Node.new(), true)
	assert_true(bool(director.get("_distortion_active")), "Pending distortion must activate after the blocking minigame closes")

	var custom_scene := CustomDeathLevel.new()
	tree.root.add_child(custom_scene)
	tree.current_scene = custom_scene
	assert_true(bool(director.call("_handle_custom_scene_death")), "Cycle levels with a custom handler must be allowed to intercept the death screen")
	assert_true(custom_scene.handled, "Custom cycle death handler must be invoked exactly through the level contract")

	var generic_scene := Node.new()
	tree.root.add_child(generic_scene)
	tree.current_scene = generic_scene
	assert_true(not bool(director.call("_handle_custom_scene_death")), "Non-cycle scenes must fall back to the default death flow")

	var distortion_rect := director.get("_distortion_rect") as ColorRect
	var transition_rect := director.get("_transition_rect") as ColorRect
	assert_true(distortion_rect != null, "GameDirector must create a distortion overlay rect")
	assert_true(transition_rect != null, "GameDirector must create a transition overlay rect")
	if distortion_rect != null and transition_rect != null:
		director.set("_distortion_active", true)
		director.set("_transition_active", true)
		distortion_rect.visible = true
		transition_rect.visible = true
		director.call("_update_for_scene", Node.new())
		assert_true(not bool(director.get("_distortion_active")), "Scene switches out of cycle levels must clear active distortion state")
		assert_true(not bool(director.get("_transition_active")), "Scene switches out of cycle levels must clear transition state")
		assert_true(not distortion_rect.visible, "Distortion overlay must not leak into non-level scenes")
		assert_true(not transition_rect.visible, "Transition overlay must not leak into non-level scenes")

	if CycleState != null:
		CycleState.set_phase(CycleState.Phase.NORMAL)

	root.queue_free()
	custom_scene.queue_free()
	generic_scene.queue_free()
	await tree.process_frame
	tree.current_scene = null
	return get_failures()
