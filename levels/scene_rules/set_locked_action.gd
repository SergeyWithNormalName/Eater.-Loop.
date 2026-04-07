extends "res://levels/scene_rules/scene_rule_action.gd"
class_name SetLockedAction

@export var door_path: NodePath
@export var locked: bool = true
@export_multiline var locked_message_override: String = ""

func execute(runner, _args: Array = []) -> void:
	var door = runner.resolve_node(door_path) as Door
	if door == null:
		return
	door.set_locked(locked, locked_message_override)
