extends "res://levels/cycles/level.gd"

@export var fridge_path: NodePath = NodePath("6thLevel/604/InteractableObjects/Fridge")
@export var door_in604_path: NodePath = NodePath("6thLevel/604/InteractableObjects/Door(In604)")
@export var note_story_path: NodePath = NodePath("NoteStory")

var _fridge: InteractiveObject = null
var _door_in604: Node = null
var _note_story: InteractiveObject = null

func _ready() -> void:
	super._ready()
	call_deferred("_wire_level11_fridge_state")

func _wire_level11_fridge_state() -> void:
	_fridge = get_node_or_null(fridge_path) as InteractiveObject
	_door_in604 = get_node_or_null(door_in604_path)
	_note_story = get_node_or_null(note_story_path) as InteractiveObject

	var fridge_done := _is_fridge_success_done()
	if _fridge != null:
		_fridge.is_completed = fridge_done
		if not _fridge.interaction_finished.is_connected(_on_fridge_successfully_interacted):
			_fridge.interaction_finished.connect(_on_fridge_successfully_interacted)

	_configure_note_dependency()
	_apply_door_lock_state(fridge_done)

func _configure_note_dependency() -> void:
	if _note_story == null or _fridge == null:
		return

	_note_story.dependency_object = _fridge
	if _note_story.has_method("_setup_dependency_listener"):
		_note_story.call("_setup_dependency_listener")
	if _note_story.has_method("_refresh_prompt_state"):
		_note_story.call("_refresh_prompt_state")

func _on_fridge_successfully_interacted() -> void:
	if _fridge != null:
		_fridge.is_completed = true
	_apply_door_lock_state(true)
	if _note_story != null and _note_story.has_method("_refresh_prompt_state"):
		_note_story.call("_refresh_prompt_state")

func _apply_door_lock_state(is_locked_state: bool) -> void:
	if _door_in604 == null:
		return
	if not _has_property(_door_in604, "is_locked"):
		return
	_door_in604.set("is_locked", is_locked_state)

func _is_fridge_success_done() -> bool:
	if GameState == null:
		return _fridge != null and _fridge.is_completed
	return bool(GameState.fridge_interacted)

func _has_property(node: Object, property_name: String) -> bool:
	for info in node.get_property_list():
		if String(info.name) == property_name:
			return true
	return false
