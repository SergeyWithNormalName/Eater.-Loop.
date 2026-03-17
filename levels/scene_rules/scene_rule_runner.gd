extends Node
class_name SceneRuleRunner

const SceneRuleScript = preload("res://levels/scene_rules/scene_rule.gd")

@export var rules: Array = []

var _fired_rules: Dictionary = {}

func _ready() -> void:
	_bind_rules()

func run_actions(actions: Array, args: Array = []) -> void:
	for action in actions:
		if action == null:
			continue
		action.execute(self, args)

func resolve_node(path: NodePath) -> Node:
	if path.is_empty():
		return null
	var resolved := get_node_or_null(path)
	if resolved != null:
		return resolved
	var host := get_parent()
	if host != null:
		return host.get_node_or_null(path)
	return null

func _bind_rules() -> void:
	for index in range(rules.size()):
		var rule = rules[index]
		if rule == null:
			continue
		match rule.trigger_kind:
			SceneRuleScript.TriggerKind.READY:
				_execute_rule(index, [])
			SceneRuleScript.TriggerKind.SIGNAL:
				_bind_signal_rule(index, rule)

func _bind_signal_rule(index: int, rule) -> void:
	var source := resolve_node(rule.source_path)
	if source == null:
		return
	if not source.has_signal(rule.signal_name):
		return
	var callback := Callable(self, "_on_rule_signal").bind(index)
	if source.is_connected(rule.signal_name, callback):
		return
	source.connect(rule.signal_name, callback)

func _on_rule_signal(index: int, arg0 = null, arg1 = null, arg2 = null, arg3 = null) -> void:
	var args: Array = []
	for value in [arg0, arg1, arg2, arg3]:
		if value != null:
			args.append(value)
	_execute_rule(index, args)

func _execute_rule(index: int, args: Array) -> void:
	var rule = _resolve_rule(index)
	if rule == null:
		return
	if rule.one_shot and _fired_rules.get(index, false):
		return
	run_actions(rule.actions, args)
	if rule.one_shot:
		_fired_rules[index] = true

func _resolve_rule(index: int):
	if index < 0 or index >= rules.size():
		return null
	return rules[index]
