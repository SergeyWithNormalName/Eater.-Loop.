extends Node

@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

var _pause_menu_layer: Node
var _pause_menu: Node
var _is_open: bool = false
var _prev_mouse_mode: int = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_menu_scene():
		return
	if _is_open:
		return
	if get_tree().paused:
		return
	_open_menu()
	get_viewport().set_input_as_handled()

func _open_menu() -> void:
	if pause_menu_scene == null:
		return
	_prev_mouse_mode = Input.get_mouse_mode()
	_ensure_menu_instance()
	if _pause_menu and _pause_menu.has_method("open_menu"):
		_pause_menu.call("open_menu")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	_is_open = true

func _request_resume() -> void:
	if _pause_menu and _pause_menu.has_method("close_menu"):
		_pause_menu.call("close_menu")
	get_tree().paused = false
	_is_open = false
	Input.set_mouse_mode(_prev_mouse_mode)

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
	)

func _is_menu_scene() -> bool:
	var current := get_tree().current_scene
	if current == null:
		return true
	return current.scene_file_path.find("/scenes/ui/") != -1
