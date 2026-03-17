extends "res://levels/scene_rules/scene_rule_action.gd"
class_name SetDependencyAction

@export var target_path: NodePath
@export var dependency_path: NodePath

func execute(runner, _args: Array = []) -> void:
	var target = runner.resolve_node(target_path) as InteractiveObject
	var dependency = runner.resolve_node(dependency_path) as InteractiveObject
	if target == null:
		return
	target.set_dependency_object(dependency)
