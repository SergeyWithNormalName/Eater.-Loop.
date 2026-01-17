extends Node

var _visible_sources: Dictionary = {}
var _in_game: bool = false
var _last_mode: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree() and get_tree().has_signal("scene_changed"):
		get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_refresh_scene_state")
	_update_mouse_mode()

func set_in_game(in_game: bool) -> void:
	_in_game = in_game
	_update_mouse_mode()

func _on_scene_changed(scene: Node) -> void:
	_update_in_game_from_scene(scene)

func _refresh_scene_state() -> void:
	_update_in_game_from_scene(get_tree().current_scene)

func _update_in_game_from_scene(scene: Node) -> void:
	var path := scene.scene_file_path if scene else ""
	_in_game = path.find("/scenes/cycles/") != -1
	_update_mouse_mode()

func request_visible(source: Object) -> void:
	if source == null:
		return
	_visible_sources[source.get_instance_id()] = weakref(source)
	_update_mouse_mode()

func release_visible(source: Object) -> void:
	if source == null:
		return
	_visible_sources.erase(source.get_instance_id())
	_update_mouse_mode()

func _update_mouse_mode() -> void:
	_cleanup_sources()
	var should_show := not _visible_sources.is_empty()
	var target := Input.MOUSE_MODE_VISIBLE if should_show else Input.MOUSE_MODE_HIDDEN
	if Input.get_mouse_mode() != target or _last_mode != target:
		Input.set_mouse_mode(target)
		_last_mode = target

func _cleanup_sources() -> void:
	if _visible_sources.is_empty():
		return
	var to_remove: Array = []
	for id in _visible_sources.keys():
		var ref: WeakRef = _visible_sources[id]
		if ref == null or ref.get_ref() == null:
			to_remove.append(id)
	for id in to_remove:
		_visible_sources.erase(id)
