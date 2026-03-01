extends "res://levels/cycles/level.gd"

const TO_BATHROOM_DEFAULT_TARGET := NodePath("../../../1thBathroom/InteractableObjects/Door(In1thBathroom)")
const TO_BEDROOM_TARGET := NodePath("../../../../Bedroom/InteractableObjects/Door(InBedroom)")

@export var door_to_bathroom_path: NodePath = NodePath("1thLevel/1thHall/InteractableObjects/Door(ToBathroom)")
@export var primary_fridge_path: NodePath = NodePath("6thLevel/604/InteractableObjects/Fridge")
@export var secondary_fridge_path: NodePath = NodePath("Stolovaya/InteractableObjects/Fridge")

var _door_to_bathroom: Node = null
var _fridges: Array[InteractiveObject] = []

func _ready() -> void:
	super._ready()
	call_deferred("_wire_bathroom_redirect")

func _wire_bathroom_redirect() -> void:
	_door_to_bathroom = get_node_or_null(door_to_bathroom_path)
	_fridges.clear()
	_register_fridge(primary_fridge_path)
	_register_fridge(secondary_fridge_path)

	for fridge in _fridges:
		if fridge == null:
			continue
		if not fridge.interaction_finished.is_connected(_on_fridge_interaction_finished):
			fridge.interaction_finished.connect(_on_fridge_interaction_finished)

	if GameState != null and GameState.has_signal("fridge_interacted_changed"):
		var on_changed := Callable(self, "_on_fridge_interacted_changed")
		if not GameState.is_connected("fridge_interacted_changed", on_changed):
			GameState.connect("fridge_interacted_changed", on_changed)

	_update_bathroom_door_target()

func _register_fridge(path: NodePath) -> void:
	var fridge := get_node_or_null(path) as InteractiveObject
	if fridge == null:
		return
	_fridges.append(fridge)

func _on_fridge_interaction_finished() -> void:
	_update_bathroom_door_target()

func _on_fridge_interacted_changed() -> void:
	_update_bathroom_door_target()

func on_fed_andrey() -> void:
	_update_bathroom_door_target()

func _update_bathroom_door_target() -> void:
	if _door_to_bathroom == null:
		return
	if not _has_property(_door_to_bathroom, "target_marker"):
		return
	var target := TO_BEDROOM_TARGET if _is_fridge_interacted() else TO_BATHROOM_DEFAULT_TARGET
	_door_to_bathroom.set("target_marker", target)

func _is_fridge_interacted() -> bool:
	if GameState != null and bool(GameState.fridge_interacted):
		return true
	for fridge in _fridges:
		if fridge != null and is_instance_valid(fridge) and bool(fridge.is_completed):
			return true
	return false

func _has_property(node: Object, property_name: String) -> bool:
	for info in node.get_property_list():
		if String(info.name) == property_name:
			return true
	return false
