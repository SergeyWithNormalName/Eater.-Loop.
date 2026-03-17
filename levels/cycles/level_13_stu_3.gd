extends "res://levels/cycles/level.gd"

const SceneRuleRunnerScript = preload("res://levels/scene_rules/scene_rule_runner.gd")
const SceneRuleScript = preload("res://levels/scene_rules/scene_rule.gd")
const SetDoorTargetFromCycleStateActionScript = preload("res://levels/scene_rules/set_door_target_from_cycle_state_action.gd")

const TO_BATHROOM_DEFAULT_TARGET := NodePath("../../../1thBathroom/InteractableObjects/Door(In1thBathroom)")
const TO_BEDROOM_TARGET := NodePath("../../../../Bedroom/InteractableObjects/Door(InBedroom)")

@export var door_to_bathroom_path: NodePath = NodePath("1thLevel/1thHall/InteractableObjects/Door(ToBathroom)")
@export var primary_fridge_path: NodePath = NodePath("6thLevel/604/InteractableObjects/Fridge")
@export var secondary_fridge_path: NodePath = NodePath("Stolovaya/InteractableObjects/Fridge")

func _ready() -> void:
	super._ready()
	_wire_bathroom_redirect()

func _wire_bathroom_redirect() -> void:
	var runner = SceneRuleRunnerScript.new()
	var update_target = SetDoorTargetFromCycleStateActionScript.new()
	update_target.door_path = door_to_bathroom_path
	update_target.condition_kind = SetDoorTargetFromCycleStateActionScript.ConditionKind.FRIDGE_INTERACTED
	update_target.target_if_true = TO_BEDROOM_TARGET
	update_target.target_if_false = TO_BATHROOM_DEFAULT_TARGET
	var ready_rule = SceneRuleScript.new()
	ready_rule.trigger_kind = SceneRuleScript.TriggerKind.READY
	ready_rule.actions = [update_target]
	var primary_rule = SceneRuleScript.new()
	primary_rule.trigger_kind = SceneRuleScript.TriggerKind.SIGNAL
	primary_rule.source_path = primary_fridge_path
	primary_rule.signal_name = "interaction_finished"
	primary_rule.one_shot = false
	primary_rule.actions = [update_target]
	var secondary_rule = SceneRuleScript.new()
	secondary_rule.trigger_kind = SceneRuleScript.TriggerKind.SIGNAL
	secondary_rule.source_path = secondary_fridge_path
	secondary_rule.signal_name = "interaction_finished"
	secondary_rule.one_shot = false
	secondary_rule.actions = [update_target]
	var state_rule = SceneRuleScript.new()
	state_rule.trigger_kind = SceneRuleScript.TriggerKind.SIGNAL
	state_rule.source_path = NodePath("/root/CycleState")
	state_rule.signal_name = "fridge_interacted_changed"
	state_rule.one_shot = false
	state_rule.actions = [update_target]
	runner.rules = [ready_rule, primary_rule, secondary_rule, state_rule]
	add_child(runner)
