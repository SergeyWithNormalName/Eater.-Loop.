extends "res://levels/scene_rules/scene_rule_action.gd"
class_name SetDoorTargetFromCycleStateAction

enum ConditionKind {
	ATE_THIS_CYCLE,
	FRIDGE_INTERACTED,
}

@export var door_path: NodePath
@export var condition_kind: ConditionKind = ConditionKind.ATE_THIS_CYCLE
@export var target_if_true: NodePath
@export var target_if_false: NodePath

func execute(runner, _args: Array = []) -> void:
	var door = runner.resolve_node(door_path) as Door
	if door == null:
		return
	var target := target_if_true if _evaluate_condition() else target_if_false
	if target.is_empty():
		return
	door.set_target_marker_path(target)

func _evaluate_condition() -> bool:
	if CycleState == null:
		return false
	match condition_kind:
		ConditionKind.FRIDGE_INTERACTED:
			return bool(CycleState.is_fridge_interacted())
		_:
			return bool(CycleState.has_eaten_this_cycle())
