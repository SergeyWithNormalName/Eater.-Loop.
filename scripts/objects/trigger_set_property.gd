extends Area2D

@export_group("Trigger")
@export var affect_on_enter: bool = true
@export var affect_on_exit: bool = false
@export var one_shot: bool = true
@export var player_group: String = "player"

@export_group("Targets")
@export var changes: Array[PropertyChange] = []
@export var target_paths: Array[NodePath] = []
@export var property_name: String = ""
@export var value: Variant

var _has_fired: bool = false

func _ready() -> void:
	input_pickable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not affect_on_enter:
		return
	if _has_fired and one_shot:
		return
	if not body.is_in_group(player_group):
		return
	_apply()

func _on_body_exited(body: Node) -> void:
	if not affect_on_exit:
		return
	if _has_fired and one_shot:
		return
	if not body.is_in_group(player_group):
		return
	_apply()

func _apply() -> void:
	if changes.size() > 0:
		for change in changes:
			_apply_change(change)
	else:
		if property_name == "":
			return
		for path in target_paths:
			var node := get_node_or_null(path)
			if node == null:
				continue
			if not _has_property(node, property_name):
				continue
			node.set(property_name, value)
	_has_fired = true

func _apply_change(change: PropertyChange) -> void:
	if change == null:
		return
	var target_path: NodePath = change.target
	var prop: String = change.property_name
	var val: Variant = change.value
	if target_path.is_empty() or prop == "":
		return
	var node := get_node_or_null(target_path)
	if node == null:
		return
	if not _has_property(node, prop):
		return
	node.set(prop, val)

func _has_property(node: Node, prop: String) -> bool:
	for info in node.get_property_list():
		if info.name == prop:
			return true
	return false
