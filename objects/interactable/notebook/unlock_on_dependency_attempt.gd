extends RefCounted
class_name UnlockOnDependencyAttempt

var enabled: bool = false
var _override_active: bool = false
var _dependency: InteractiveObject = null
var _on_unlock_requested: Callable = Callable()

func configure(enabled_value: bool, on_unlock_requested: Callable) -> void:
	enabled = enabled_value
	_on_unlock_requested = on_unlock_requested

func update_dependency(dependency: InteractiveObject) -> void:
	if _dependency != null and is_instance_valid(_dependency):
		if _dependency.interaction_requested.is_connected(_on_dependency_interaction_requested):
			_dependency.interaction_requested.disconnect(_on_dependency_interaction_requested)
	_dependency = dependency
	if not enabled:
		return
	if _dependency == null or not is_instance_valid(_dependency):
		return
	if not _dependency.interaction_requested.is_connected(_on_dependency_interaction_requested):
		_dependency.interaction_requested.connect(_on_dependency_interaction_requested)

func is_active() -> bool:
	return _override_active

func set_active(value: bool) -> void:
	_override_active = value

func capture_state() -> Dictionary:
	return {
		"dependency_override": _override_active,
	}

func apply_state(state: Dictionary) -> void:
	_override_active = bool(state.get("dependency_override", _override_active))

func _on_dependency_interaction_requested(_player: Node = null) -> void:
	if not enabled:
		return
	if _override_active:
		return
	_override_active = true
	if _on_unlock_requested.is_valid():
		_on_unlock_requested.call()
