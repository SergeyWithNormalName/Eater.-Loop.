extends "res://tests/test_case.gd"

const ENEMY_SCENE_PATH := "res://enemies/light_sensitive/enemy_light_sensitive.tscn"
const PICKUP_FLASHLIGHT_SCENE_PATH := "res://objects/interactable/flashlight/pickup_flashlight.tscn"

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var enemy_scene := assert_loads(ENEMY_SCENE_PATH) as PackedScene
	var pickup_scene := assert_loads(PICKUP_FLASHLIGHT_SCENE_PATH) as PackedScene
	assert_true(enemy_scene != null, "EnemyLightSensitive scene failed to load")
	assert_true(pickup_scene != null, "Pickup flashlight scene failed to load")
	if enemy_scene == null or pickup_scene == null:
		return get_failures()

	var root := Node2D.new()
	tree.root.add_child(root)

	var pickup_flashlight := pickup_scene.instantiate()
	pickup_flashlight.global_position = Vector2.ZERO
	root.add_child(pickup_flashlight)

	var enemy := enemy_scene.instantiate()
	enemy.chase_player = false
	enemy.enable_chase_music = false
	enemy.chase_music = null
	root.add_child(enemy)
	await tree.process_frame

	enemy.global_position = pickup_flashlight.global_position + Vector2.RIGHT * 240.0
	await tree.physics_frame
	await tree.physics_frame
	assert_true(bool(enemy.get("_lamp_frozen")), "Light-sensitive enemy must freeze inside the visible beam of a placed flashlight")

	enemy.global_position = pickup_flashlight.global_position + Vector2.LEFT * 240.0
	await tree.physics_frame
	await tree.physics_frame
	assert_true(not bool(enemy.get("_lamp_frozen")), "Light-sensitive enemy must not freeze behind a placed flashlight")

	root.queue_free()
	await tree.process_frame
	return get_failures()
