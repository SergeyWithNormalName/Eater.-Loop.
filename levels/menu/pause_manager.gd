extends Node

@export var pause_menu_scene: PackedScene = preload("res://levels/menu/pause_menu.tscn")

var _pause_menu_layer: Node
var _pause_menu: Node
var _is_open: bool = false
var _prev_paused_state: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_menu_scene():
		return
	if _is_open:
		return
	if _is_search_key_minigame_active():
		return
	if get_tree().paused and not _is_minigame_active():
		return
	_open_menu()
	get_viewport().set_input_as_handled()

func _open_menu() -> void:
	if pause_menu_scene == null:
		return
	_prev_paused_state = get_tree().paused
	_ensure_menu_instance()
	if _pause_menu and _pause_menu.has_method("open_menu"):
		_pause_menu.call("open_menu")
	get_tree().paused = true
	_is_open = true
	if MinigameController and MinigameController.has_method("set_pause_menu_open"):
		MinigameController.set_pause_menu_open(true)

func _request_resume() -> void:
	if _pause_menu and _pause_menu.has_method("close_menu"):
		_pause_menu.call("close_menu")
	get_tree().paused = _prev_paused_state
	_is_open = false
	if MinigameController and MinigameController.has_method("set_pause_menu_open"):
		MinigameController.set_pause_menu_open(false)

func _ensure_menu_instance() -> void:
	if is_instance_valid(_pause_menu_layer):
		return
	_pause_menu_layer = pause_menu_scene.instantiate()
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(_pause_menu_layer)
	_pause_menu = _pause_menu_layer.get_node_or_null("PauseMenu")
	if _pause_menu and _pause_menu.has_signal("resume_requested"):
		_pause_menu.connect("resume_requested", _request_resume)
	_pause_menu_layer.tree_exiting.connect(func():
		_pause_menu_layer = null
		_pause_menu = null
		_is_open = false
		if MinigameController and MinigameController.has_method("set_pause_menu_open"):
			MinigameController.set_pause_menu_open(false)
	)

func _is_menu_scene() -> bool:
	var current := get_tree().current_scene
	if current == null:
		return true
	return current.scene_file_path.find("/levels/menu/") != -1

func _is_minigame_active() -> bool:
	var nodes := get_tree().get_nodes_in_group("minigame_ui")
	for node in nodes:
		if node is CanvasItem and node.visible:
			return true
		if node.is_inside_tree():
			return true
	return false

func _is_search_key_minigame_active() -> bool:
	var nodes := get_tree().get_nodes_in_group("search_key_minigame")
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if MinigameController and MinigameController.has_method("is_active"):
			if MinigameController.is_active(node):
				return true
			continue
		if not node.is_inside_tree():
			continue
		if node is CanvasItem and not node.visible:
			continue
		return true
	return false

func is_pause_menu_open() -> bool:
	return _is_open
