extends "res://levels/scene_rules/scene_rule_action.gd"
class_name SetInteractionEnabledAction

@export var target_path: NodePath
@export var enabled: bool = true

func execute(runner, _args: Array = []) -> void:
	var target = runner.resolve_node(target_path) as InteractiveObject
	if target == null:
		return
	target.set_interaction_enabled(enabled)
