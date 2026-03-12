extends "res://tests/test_case.gd"

const TEST_SCENE_PATH := "res://levels/cycles/test_checkpoint_scene.tscn"

class DummyPlayer:
	extends CharacterBody2D

	var label: String = ""

	func _ready() -> void:
		add_to_group("player")
		add_to_group("checkpoint_stateful")

	func capture_checkpoint_state() -> Dictionary:
		return {"label": label}

	func apply_checkpoint_state(state: Dictionary) -> void:
		label = str(state.get("label", label))

class DummyEnemy:
	extends CharacterBody2D

	var state_value: int = 0

	func _ready() -> void:
		add_to_group("checkpoint_stateful")

	func capture_checkpoint_state() -> Dictionary:
		return {"state_value": state_value}

	func apply_checkpoint_state(state: Dictionary) -> void:
		state_value = int(state.get("state_value", state_value))

class DummyPickup:
	extends Node2D

	func _ready() -> void:
		add_to_group("checkpoint_stateful")

func run() -> Array[String]:
	await _test_fridge_checkpoint_restores_scene_snapshot()
	return get_failures()

func _test_fridge_checkpoint_restores_scene_snapshot() -> void:
	assert_true(GameState != null, "GameState autoload is missing")
	assert_true(CycleState != null, "CycleState autoload is missing")
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if GameState == null or CycleState == null or tree == null:
		return

	GameState.reset_run()
	CycleState.reset_cycle_state()
	GameState.set_current_scene_path(TEST_SCENE_PATH)

	var scene_a := Node2D.new()
	scene_a.name = "CheckpointSceneA"
	var player_a := DummyPlayer.new()
	player_a.name = "Player"
	player_a.global_position = Vector2(120.0, 40.0)
	player_a.label = "start"
	var enemy_a := DummyEnemy.new()
	enemy_a.name = "Enemy"
	enemy_a.global_position = Vector2(500.0, 64.0)
	enemy_a.state_value = 1
	var pickup_a := DummyPickup.new()
	pickup_a.name = "Pickup"

	scene_a.add_child(player_a)
	scene_a.add_child(enemy_a)
	scene_a.add_child(pickup_a)
	tree.root.add_child(scene_a)
	await tree.process_frame

	GameState.capture_level_start_checkpoint(scene_a)

	CycleState.mark_fridge_interacted()
	player_a.global_position = Vector2(860.0, 160.0)
	player_a.label = "fridge"
	enemy_a.global_position = Vector2(1440.0, 96.0)
	enemy_a.state_value = 42
	pickup_a.queue_free()
	await tree.process_frame

	GameState.capture_fridge_checkpoint(scene_a)

	CycleState.mark_phone_picked()
	player_a.global_position = Vector2(40.0, 10.0)
	enemy_a.state_value = 99

	assert_true(GameState.restore_respawn_checkpoint(), "Respawn checkpoint must be restorable after fridge capture")
	assert_true(not CycleState.phone_picked, "Respawn restore must roll CycleState back to the checkpoint snapshot")

	scene_a.queue_free()
	await tree.process_frame

	var scene_b := Node2D.new()
	scene_b.name = "CheckpointSceneB"
	var player_b := DummyPlayer.new()
	player_b.name = "Player"
	player_b.global_position = Vector2.ZERO
	var enemy_b := DummyEnemy.new()
	enemy_b.name = "Enemy"
	enemy_b.state_value = 0
	var pickup_b := DummyPickup.new()
	pickup_b.name = "Pickup"

	scene_b.add_child(player_b)
	scene_b.add_child(enemy_b)
	scene_b.add_child(pickup_b)
	tree.root.add_child(scene_b)
	await tree.process_frame

	assert_true(GameState.apply_checkpoint_to_scene(scene_b), "Checkpoint scene snapshot must apply to a reloaded scene")
	await tree.process_frame

	assert_eq(player_b.global_position, Vector2(860.0, 160.0), "Player position must restore from the fridge checkpoint snapshot")
	assert_eq(player_b.label, "fridge", "Player custom state must restore from the fridge checkpoint snapshot")
	assert_eq(enemy_b.global_position, Vector2(1440.0, 96.0), "Enemy position must restore from the fridge checkpoint snapshot")
	assert_eq(enemy_b.state_value, 42, "Enemy custom state must restore from the fridge checkpoint snapshot")
	assert_true(scene_b.get_node_or_null("Pickup") == null, "Removed checkpoint participants must stay removed after respawn")

	scene_b.queue_free()
	await tree.process_frame
	GameState.reset_run()
	CycleState.reset_cycle_state()
