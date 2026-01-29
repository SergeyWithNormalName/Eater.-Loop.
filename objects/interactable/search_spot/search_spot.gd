extends "res://objects/interactable/interactive_object.gd"

@export_group("Search Settings")
@export var minigame_scene: PackedScene
@export var key_id: String = "door_key"
@export var key_texture: Texture2D
@export var trash_textures: Array[Texture2D] = []
@export var trash_min: int = 5
@export var trash_max: int = 15

@export_group("Minigame Session")
@export var pause_game: bool = false
@export var enable_gamepad_cursor: bool = true
@export var gamepad_cursor_speed: float = 800.0

var has_key: bool = false
var is_searched_empty: bool = false

var _current_minigame: Node = null
var _layout_state: Dictionary = {}

func set_has_key(value: bool) -> void:
	has_key = value
	if value:
		is_searched_empty = false

func _on_interact() -> void:
	if _current_minigame != null:
		return
	if is_searched_empty:
		if UIMessage:
			UIMessage.show_text("Тут больше ничего нет.")
		return
	if minigame_scene == null:
		push_warning("SearchSpot: minigame_scene не задан.")
		return

	var minigame = minigame_scene.instantiate()
	_current_minigame = minigame
	_add_minigame_to_scene(minigame)

	if minigame.has_method("setup"):
		var layout_payload: Dictionary = {}
		if not _layout_state.is_empty():
			layout_payload = _layout_state.duplicate(true)
		minigame.setup({
			"has_key": has_key,
			"key_id": key_id,
			"key_texture": key_texture,
			"trash_range": Vector2i(trash_min, trash_max),
			"trash_textures": trash_textures,
			"layout_state": layout_payload
		})

	set_prompts_enabled(false)
	if MinigameController and MinigameController.has_signal("minigame_finished"):
		MinigameController.minigame_finished.connect(_on_minigame_finished)
	if MinigameController:
		MinigameController.start_minigame(minigame, {
			"pause_game": pause_game,
			"enable_gamepad_cursor": enable_gamepad_cursor,
			"gamepad_cursor_speed": gamepad_cursor_speed,
			"block_player_movement": true
		})

func _on_minigame_finished(minigame: Node, success: bool) -> void:
	if minigame != _current_minigame:
		return
	if MinigameController and MinigameController.minigame_finished.is_connected(_on_minigame_finished):
		MinigameController.minigame_finished.disconnect(_on_minigame_finished)
	_current_minigame = null
	set_prompts_enabled(true)

	if is_instance_valid(minigame) and minigame.has_method("get_layout_state"):
		_layout_state = minigame.get_layout_state()

	if success and has_key:
		has_key = false
		is_searched_empty = true

func _add_minigame_to_scene(minigame: Node) -> void:
	if minigame == null:
		return
	if MinigameController and MinigameController.has_method("attach_minigame"):
		MinigameController.attach_minigame(minigame)
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if parent:
		parent.add_child(minigame)
