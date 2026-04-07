extends "res://levels/cycles/level.gd"

const SceneRuleRunnerScript = preload("res://levels/scene_rules/scene_rule_runner.gd")
const SceneRuleScript = preload("res://levels/scene_rules/scene_rule.gd")
const SetLockedActionScript = preload("res://levels/scene_rules/set_locked_action.gd")

const LOCKED_DOOR_MESSAGE := "Дверь заперта"

@export var fridge_path: NodePath = NodePath("Hall2/InteractableObjects/Fridge")
@export var hall2_left_door_path: NodePath = NodePath("Hall2/InteractableObjects/Door(ToParents)")
@export var hall2_right_door_path: NodePath = NodePath("Hall2/InteractableObjects/Door(ToParents)2")

func _ready() -> void:
	super._ready()
	_setup_level_logic()

func _setup_level_logic() -> void:
	_apply_unified_locked_messages()
	var runner = SceneRuleRunnerScript.new()
	var ready_rule = SceneRuleScript.new()
	ready_rule.trigger_kind = SceneRuleScript.TriggerKind.READY
	ready_rule.actions = _build_post_fridge_actions() if _is_post_fridge_state() else _build_pre_fridge_actions()
	var signal_rule = SceneRuleScript.new()
	signal_rule.trigger_kind = SceneRuleScript.TriggerKind.SIGNAL
	signal_rule.source_path = fridge_path
	signal_rule.signal_name = "interaction_finished"
	signal_rule.one_shot = true
	signal_rule.actions = _build_post_fridge_actions()
	runner.rules = [ready_rule, signal_rule]
	add_child(runner)

func _build_pre_fridge_actions() -> Array:
	var left = SetLockedActionScript.new()
	left.door_path = hall2_left_door_path
	left.locked = false
	left.locked_message_override = "Дверь в коридор."
	var right = SetLockedActionScript.new()
	right.door_path = hall2_right_door_path
	right.locked = false
	right.locked_message_override = "Сначала нужно сделать что-то другое..."
	return [left, right]

func _build_post_fridge_actions() -> Array:
	var left = SetLockedActionScript.new()
	left.door_path = hall2_left_door_path
	left.locked = true
	left.locked_message_override = "Щелк. Эту дверь заклинило. Придется идти через другую."
	var right = SetLockedActionScript.new()
	right.door_path = hall2_right_door_path
	right.locked = false
	right.locked_message_override = "Дверь в коридор."
	return [left, right]

func _apply_unified_locked_messages() -> void:
	for door_node in get_tree().get_nodes_in_group(GroupNames.DOORS):
		var door := door_node as Door
		if door == null:
			continue
		door.locked_message = LOCKED_DOOR_MESSAGE
		door.door_locked_message = LOCKED_DOOR_MESSAGE

func _is_post_fridge_state() -> bool:
	return CycleState != null and CycleState.is_fridge_interacted()
