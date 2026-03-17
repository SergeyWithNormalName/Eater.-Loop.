extends "res://levels/scene_rules/scene_rule_action.gd"
class_name SetDoorTargetAction

@export var door_path: NodePath
@export var target_marker: NodePath

func execute(runner, _args: Array = []) -> void:
	var door = runner.resolve_node(door_path) as Door
	if door == null:
		return
	door.set_target_marker_path(target_marker)
