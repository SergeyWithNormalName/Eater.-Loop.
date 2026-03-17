extends Resource
class_name SceneRule

enum TriggerKind {
	READY,
	SIGNAL,
}

@export var trigger_kind: TriggerKind = TriggerKind.READY
@export var source_path: NodePath
@export var signal_name: String = ""
@export var one_shot: bool = true
@export var actions: Array = []
