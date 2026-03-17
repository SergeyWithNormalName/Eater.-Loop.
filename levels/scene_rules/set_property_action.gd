extends "res://levels/scene_rules/scene_rule_action.gd"
class_name SetPropertyAction

@export var target_path: NodePath
@export var property_name: String = ""
@export var value: Variant

func execute(runner, _args: Array = []) -> void:
	if property_name == "":
		return
	var target = runner.resolve_node(target_path)
	if target == null:
		return
	target.set(property_name, value)
