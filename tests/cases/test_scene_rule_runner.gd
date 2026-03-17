extends "res://tests/test_case.gd"

const SceneRuleRunnerScript = preload("res://levels/scene_rules/scene_rule_runner.gd")
const SceneRuleScript = preload("res://levels/scene_rules/scene_rule.gd")
const SetPropertyActionScript = preload("res://levels/scene_rules/set_property_action.gd")
const SetInteractionEnabledActionScript = preload("res://levels/scene_rules/set_interaction_enabled_action.gd")
const InteractiveObjectScript = preload("res://objects/interactable/interactive_object.gd")

class SignalSource:
	extends Node

	signal ping
	signal pong

class CounterNode:
	extends Node

	var count: int = 0

class CounterAction:
	extends Resource

	var target_path: NodePath

	func execute(runner, _args: Array = []) -> void:
		var target = runner.resolve_node(target_path)
		if target != null:
			target.count += 1

func run() -> Array[String]:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree is not available")
	if tree == null:
		return get_failures()

	var host := Node.new()
	tree.root.add_child(host)

	var source := SignalSource.new()
	source.name = "Source"
	host.add_child(source)

	var counter := CounterNode.new()
	counter.name = "Counter"
	host.add_child(counter)

	var interactable := InteractiveObjectScript.new()
	interactable.name = "Interactable"
	host.add_child(interactable)
	await tree.process_frame

	var set_count = SetPropertyActionScript.new()
	set_count.target_path = NodePath("Counter")
	set_count.property_name = "count"
	set_count.value = 3

	var disable_interaction = SetInteractionEnabledActionScript.new()
	disable_interaction.target_path = NodePath("Interactable")
	disable_interaction.enabled = false

	var missing_target = SetPropertyActionScript.new()
	missing_target.target_path = NodePath("Missing")
	missing_target.property_name = "count"
	missing_target.value = 99

	var one_shot_action := CounterAction.new()
	one_shot_action.target_path = NodePath("Counter")

	var repeat_action := CounterAction.new()
	repeat_action.target_path = NodePath("Counter")

	var ready_rule = SceneRuleScript.new()
	ready_rule.trigger_kind = SceneRuleScript.TriggerKind.READY
	ready_rule.actions = [set_count, disable_interaction, missing_target]

	var one_shot_rule = SceneRuleScript.new()
	one_shot_rule.trigger_kind = SceneRuleScript.TriggerKind.SIGNAL
	one_shot_rule.source_path = NodePath("Source")
	one_shot_rule.signal_name = "ping"
	one_shot_rule.one_shot = true
	one_shot_rule.actions = [one_shot_action]

	var repeat_rule = SceneRuleScript.new()
	repeat_rule.trigger_kind = SceneRuleScript.TriggerKind.SIGNAL
	repeat_rule.source_path = NodePath("Source")
	repeat_rule.signal_name = "pong"
	repeat_rule.one_shot = false
	repeat_rule.actions = [repeat_action]

	var runner = SceneRuleRunnerScript.new()
	runner.rules = [ready_rule, one_shot_rule, repeat_rule]
	host.add_child(runner)
	await tree.process_frame

	assert_eq(counter.count, 3, "READY rules must run immediately after runner enters the tree")
	assert_true(not interactable.handle_input, "SetInteractionEnabledAction must disable interaction")

	source.ping.emit()
	source.ping.emit()
	source.pong.emit()
	source.pong.emit()

	assert_eq(counter.count, 6, "Signal rules must support both one-shot and repeating execution")

	host.queue_free()
	await tree.process_frame
	return get_failures()
