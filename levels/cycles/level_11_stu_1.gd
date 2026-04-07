extends "res://levels/cycles/level.gd"

const SceneRuleRunnerScript = preload("res://levels/scene_rules/scene_rule_runner.gd")
const SceneRuleScript = preload("res://levels/scene_rules/scene_rule.gd")
const SetPropertyActionScript = preload("res://levels/scene_rules/set_property_action.gd")
const SetDependencyActionScript = preload("res://levels/scene_rules/set_dependency_action.gd")
const RefreshInteractionStateActionScript = preload("res://levels/scene_rules/refresh_interaction_state_action.gd")
const SetLockedActionScript = preload("res://levels/scene_rules/set_locked_action.gd")
const SetDoorTargetActionScript = preload("res://levels/scene_rules/set_door_target_action.gd")

@export var fridge_path: NodePath = NodePath("6thLevel/604/InteractableObjects/Fridge")
@export var door_in604_path: NodePath = NodePath("6thLevel/604/InteractableObjects/Door(In604)")
@export var door_to701_path: NodePath = NodePath("7thLevel/7thHall/InteractableObjects/Door(To701)")
@export var door_to701_target_before_fridge: NodePath = NodePath("../../../701/InteractableObjects/Door(In701)")
@export var door_to701_target_after_fridge: NodePath = NodePath("../../../../Bedroom/InteractableObjects/Door(InBedroom)")
@export var note_story_path: NodePath = NodePath("NoteStory")

func _ready() -> void:
	super._ready()
	_wire_level11_fridge_state()

func _wire_level11_fridge_state() -> void:
	var runner = SceneRuleRunnerScript.new()
	var fridge_done := _is_fridge_success_done()
	var ready_rule = SceneRuleScript.new()
	ready_rule.trigger_kind = SceneRuleScript.TriggerKind.READY
	ready_rule.actions = _build_ready_actions(fridge_done)
	var signal_rule = SceneRuleScript.new()
	signal_rule.trigger_kind = SceneRuleScript.TriggerKind.SIGNAL
	signal_rule.source_path = fridge_path
	signal_rule.signal_name = "interaction_finished"
	signal_rule.one_shot = true
	signal_rule.actions = _build_post_fridge_actions()
	runner.rules = [ready_rule, signal_rule]
	add_child(runner)

func _build_ready_actions(fridge_done: bool) -> Array:
	var set_fridge_completed = SetPropertyActionScript.new()
	set_fridge_completed.target_path = fridge_path
	set_fridge_completed.property_name = "is_completed"
	set_fridge_completed.value = fridge_done
	var set_dependency = SetDependencyActionScript.new()
	set_dependency.target_path = note_story_path
	set_dependency.dependency_path = fridge_path
	var refresh_note = RefreshInteractionStateActionScript.new()
	refresh_note.target_path = note_story_path
	var set_locked = SetLockedActionScript.new()
	set_locked.door_path = door_in604_path
	set_locked.locked = fridge_done
	var set_target = SetDoorTargetActionScript.new()
	set_target.door_path = door_to701_path
	set_target.target_marker = door_to701_target_after_fridge if fridge_done else door_to701_target_before_fridge
	return [set_fridge_completed, set_dependency, refresh_note, set_locked, set_target]

func _build_post_fridge_actions() -> Array:
	var set_fridge_completed = SetPropertyActionScript.new()
	set_fridge_completed.target_path = fridge_path
	set_fridge_completed.property_name = "is_completed"
	set_fridge_completed.value = true
	var set_locked = SetLockedActionScript.new()
	set_locked.door_path = door_in604_path
	set_locked.locked = true
	var set_target = SetDoorTargetActionScript.new()
	set_target.door_path = door_to701_path
	set_target.target_marker = door_to701_target_after_fridge
	var refresh_note = RefreshInteractionStateActionScript.new()
	refresh_note.target_path = note_story_path
	return [set_fridge_completed, set_locked, set_target, refresh_note]

func _is_fridge_success_done() -> bool:
	if CycleState == null:
		var fridge := get_node_or_null(fridge_path) as InteractiveObject
		return fridge != null and fridge.is_completed
	return bool(CycleState.is_fridge_interacted())
