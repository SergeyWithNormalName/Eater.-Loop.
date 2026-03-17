extends "res://levels/scene_rules/scene_rule_action.gd"
class_name StartCrazyLevelEventAction

const CrazyLevelEventScript := preload("res://levels/cycles/crazy_level_event.gd")

@export var event_path: NodePath

func execute(runner: Node, _args: Array = []) -> void:
	var event_node: Node = runner.resolve_node(event_path)
	if event_node == null or not (event_node is CrazyLevelEventScript):
		return
	event_node.start_event()
