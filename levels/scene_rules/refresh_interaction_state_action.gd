extends "res://levels/scene_rules/scene_rule_action.gd"
class_name RefreshInteractionStateAction

@export var target_path: NodePath

func execute(runner, _args: Array = []) -> void:
	var target = runner.resolve_node(target_path) as InteractiveObject
	if target == null:
		return
	target.refresh_interaction_state()
