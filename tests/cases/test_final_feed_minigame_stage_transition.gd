extends "res://tests/test_case.gd"

const FINAL_FEED_SCENE_PATH := "res://levels/minigames/feeding/final_feed_minigame.tscn"
const FACE_STAGE_A := preload("res://levels/minigames/feeding/andreys_faces/HappyEat.png")
const FACE_STAGE_B := preload("res://levels/minigames/feeding/andreys_faces/SadEat.png")
const FOOD_STAGE_A := preload("res://levels/minigames/feeding/food/dumpling/food_dumpling.tscn")
const FOOD_STAGE_B := preload("res://levels/minigames/feeding/food/cookie/food_cookie_1.tscn")

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var minigame_scene := assert_loads(FINAL_FEED_SCENE_PATH) as PackedScene
	assert_true(minigame_scene != null, "Final feed minigame scene failed to load")
	if minigame_scene == null:
		return get_failures()

	var minigame := minigame_scene.instantiate()
	tree.root.add_child(minigame)
	await tree.process_frame
	await tree.process_frame

	minigame.stage_glitch_duration = 0.18
	minigame.stage_pause_after_glitch = 0.14
	minigame.setup_final_stages([
		{
			"face": FACE_STAGE_A,
			"food_count": 1,
			"food_scenes": [FOOD_STAGE_A],
		},
		{
			"face": FACE_STAGE_B,
			"food_count": 1,
			"food_scenes": [FOOD_STAGE_B],
		},
	], null, null, null, null)
	await tree.process_frame
	await tree.process_frame

	assert_eq(int(minigame.get("_stage_index")), 0, "Final feed minigame must start from the first stage")
	assert_true(minigame.andrey_sprite.texture == FACE_STAGE_A, "Initial stage face must match the first configured stage")

	var first_food := _find_first_food(minigame)
	assert_true(first_food != null, "Initial stage must spawn an interactable food item")
	if first_food != null:
		first_food.call("eat_me")
	await tree.process_frame
	await tree.process_frame

	assert_true(bool(minigame.get("_stage_transition_active")), "Stage transition must remain active while glitch shader is playing")
	assert_eq(int(minigame.get("_stage_index")), 0, "Next stage must not activate in the first frame of the glitch transition")
	assert_true(minigame.andrey_sprite.texture == FACE_STAGE_A, "Andrey face must not swap in the first frame of the glitch transition")

	await tree.create_timer(0.12, true).timeout

	assert_true(bool(minigame.get("_stage_transition_active")), "Stage transition must still be active when the next stage appears in the middle of the glitch")
	assert_eq(int(minigame.get("_stage_index")), 1, "Next stage must activate around the middle of the glitch transition")
	assert_true(minigame.andrey_sprite.texture == FACE_STAGE_B, "Next stage face must swap during the middle of the glitch transition")

	var during_glitch_food := _find_first_food(minigame)
	assert_true(during_glitch_food != null, "Next stage food must spawn during the glitch transition, not only after it finishes")
	if during_glitch_food != null:
		assert_true(not during_glitch_food.input_pickable, "Next stage food must stay non-interactive until the glitch transition finishes")
		assert_true(not bool(during_glitch_food.call("is_gamepad_focusable")), "Next stage food must stay unavailable for gamepad confirm during the glitch transition")

	await tree.create_timer(0.33, true).timeout

	assert_true(not bool(minigame.get("_stage_transition_active")), "Stage transition must end after glitch shader and hold delay finish")
	var ready_food := _find_first_food(minigame)
	assert_true(ready_food != null, "Next stage food must still exist after the glitch transition finishes")
	if ready_food != null:
		assert_true(ready_food.input_pickable, "Next stage food must become interactive again after the glitch transition finishes")

	minigame.queue_free()
	await tree.process_frame
	return get_failures()

func _find_first_food(minigame: Node) -> Area2D:
	var food_container := minigame.get_node_or_null("Control/FoodContainer")
	if food_container == null:
		return null
	for child in food_container.get_children():
		if child is Area2D and child.has_method("set_interaction_enabled"):
			return child as Area2D
	return null
