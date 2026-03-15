extends "res://tests/test_case.gd"

const OPAQUE_FULLSCREEN_SCENE_PATH := "res://levels/minigames/labs/sql/sql_minigame.tscn"
const TRANSLUCENT_BACKDROP_SCENE_PATH := "res://levels/minigames/search_key/search_minigame.tscn"
const TEXTURE_BACKDROP_SCENE_PATH := "res://levels/minigames/labs/LLM/llm_minigame.tscn"

func run() -> Array[String]:
	assert_true(MinigameController != null, "MinigameController autoload is missing")
	if MinigameController == null:
		return get_failures()
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var host := Node.new()
	tree.root.add_child(host)
	await tree.process_frame

	await _assert_opaque_fullscreen_scene_skips_extra_backdrop(host, tree)
	await _assert_translucent_scene_gets_extra_backdrop(host, tree)
	await _assert_texture_background_scene_gets_extra_backdrop(host, tree)

	host.queue_free()
	await tree.process_frame
	return get_failures()

func _assert_opaque_fullscreen_scene_skips_extra_backdrop(host: Node, tree: SceneTree) -> void:
	var minigame_scene := assert_loads(OPAQUE_FULLSCREEN_SCENE_PATH) as PackedScene
	assert_true(minigame_scene != null, "Opaque fullscreen mini-game scene failed to load")
	if minigame_scene == null:
		return

	var minigame := minigame_scene.instantiate()
	MinigameController.attach_minigame(minigame, -1, host)
	await tree.process_frame

	var backdrops: Dictionary = MinigameController.get("_minigame_backdrops")
	assert_true(not backdrops.has(minigame.get_instance_id()), "Mini-games with their own opaque fullscreen background must not receive an extra backdrop layer")

	minigame.queue_free()
	await tree.process_frame

func _assert_translucent_scene_gets_extra_backdrop(host: Node, tree: SceneTree) -> void:
	var minigame_scene := assert_loads(TRANSLUCENT_BACKDROP_SCENE_PATH) as PackedScene
	assert_true(minigame_scene != null, "Translucent mini-game scene failed to load")
	if minigame_scene == null:
		return

	var minigame := minigame_scene.instantiate()
	MinigameController.attach_minigame(minigame, -1, host)
	await tree.process_frame

	var backdrops: Dictionary = MinigameController.get("_minigame_backdrops")
	assert_true(backdrops.has(minigame.get_instance_id()), "Mini-games with only a translucent fullscreen overlay must still receive the shared black backdrop")

	minigame.queue_free()
	await tree.process_frame

func _assert_texture_background_scene_gets_extra_backdrop(host: Node, tree: SceneTree) -> void:
	var minigame_scene := assert_loads(TEXTURE_BACKDROP_SCENE_PATH) as PackedScene
	assert_true(minigame_scene != null, "Texture-backed mini-game scene failed to load")
	if minigame_scene == null:
		return

	var minigame := minigame_scene.instantiate()
	MinigameController.attach_minigame(minigame, -1, host)
	await tree.process_frame

	var backdrops: Dictionary = MinigameController.get("_minigame_backdrops")
	assert_true(backdrops.has(minigame.get_instance_id()), "Mini-games with fullscreen texture backgrounds must still receive the shared black backdrop behind the texture")

	minigame.queue_free()
	await tree.process_frame
