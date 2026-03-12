extends "res://levels/cycles/level.gd"

@export var fridge_path: NodePath = NodePath("6thLevel/604/InteractableObjects/Fridge")
@export var door_in604_path: NodePath = NodePath("6thLevel/604/InteractableObjects/Door(In604)")
@export var door_to701_path: NodePath = NodePath("7thLevel/7thHall/InteractableObjects/Door(To701)")
@export var door_to701_target_before_fridge: NodePath = NodePath("../../../701/InteractableObjects/Door(In701)")
@export var door_to701_target_after_fridge: NodePath = NodePath("../../../../Bedroom/InteractableObjects/Door(InBedroom)")
@export var note_story_path: NodePath = NodePath("NoteStory")

var _fridge: InteractiveObject = null
var _door_in604: Node = null
var _door_to701: Node = null
var _note_story: InteractiveObject = null

func _ready() -> void:
	super._ready()
	call_deferred("_wire_level11_fridge_state")

func _wire_level11_fridge_state() -> void:
	_fridge = get_node_or_null(fridge_path) as InteractiveObject
	_door_in604 = get_node_or_null(door_in604_path)
	_door_to701 = get_node_or_null(door_to701_path)
	_note_story = get_node_or_null(note_story_path) as InteractiveObject

	var fridge_done := _is_fridge_success_done()
	if _fridge != null:
		_fridge.is_completed = fridge_done
		if not _fridge.interaction_finished.is_connected(_on_fridge_successfully_interacted):
			_fridge.interaction_finished.connect(_on_fridge_successfully_interacted)

	_configure_note_dependency()
	_apply_door_lock_state(fridge_done)
	_apply_to701_target(fridge_done)

func _configure_note_dependency() -> void:
	if _note_story == null or _fridge == null:
		return

	_note_story.set_dependency_object(_fridge)
	_note_story.refresh_interaction_state()

func _on_fridge_successfully_interacted() -> void:
	if _fridge != null:
		_fridge.is_completed = true
	_apply_door_lock_state(true)
	_apply_to701_target(true)
	if _note_story != null:
		_note_story.refresh_interaction_state()

func _apply_door_lock_state(is_locked_state: bool) -> void:
	if _door_in604 == null or not _door_in604.has_method("set_locked"):
		return
	_door_in604.call("set_locked", is_locked_state)

func _apply_to701_target(fridge_done: bool) -> void:
	if _door_to701 == null or not _door_to701.has_method("set_target_marker_path"):
		return

	var target_marker: NodePath = door_to701_target_after_fridge if fridge_done else door_to701_target_before_fridge
	if target_marker.is_empty():
		return
	_door_to701.call("set_target_marker_path", target_marker)

func _is_fridge_success_done() -> bool:
	if CycleState == null:
		return _fridge != null and _fridge.is_completed
	if CycleState.has_method("is_fridge_interacted"):
		return bool(CycleState.is_fridge_interacted())
	return false
