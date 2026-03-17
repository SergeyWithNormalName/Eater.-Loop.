extends RefCounted
class_name CodeLockGate

var require_access_code: bool = false
var access_code: String = "1234"
var access_code_failed_message: String = ""
var code_lock_scene: PackedScene = null
var unlocked: bool = false

var _active_lock: Node = null
var _on_unlock_success: Callable = Callable()
var _on_unlock_failed_exit: Callable = Callable()
var _on_interacting_changed: Callable = Callable()

func configure(
	require_access_code_value: bool,
	access_code_value: String,
	access_code_failed_message_value: String,
	code_lock_scene_value: PackedScene
) -> void:
	require_access_code = require_access_code_value
	access_code = access_code_value
	access_code_failed_message = access_code_failed_message_value
	code_lock_scene = code_lock_scene_value

func needs_unlock() -> bool:
	return require_access_code and not unlocked

func request_unlock(
	host: Node,
	attach_callback: Callable,
	on_unlock_success: Callable,
	on_unlock_failed_exit: Callable,
	on_interacting_changed: Callable
) -> bool:
	if not needs_unlock():
		return false
	if code_lock_scene == null:
		push_warning("%s: Не назначена сцена Code Lock!" % host.name)
		return true
	var lock_instance := code_lock_scene.instantiate()
	_active_lock = lock_instance
	_on_unlock_success = on_unlock_success
	_on_unlock_failed_exit = on_unlock_failed_exit
	_on_interacting_changed = on_interacting_changed
	_apply_code_value(lock_instance)
	if lock_instance.has_signal("unlocked"):
		lock_instance.unlocked.connect(_handle_unlock_success)
	lock_instance.tree_exited.connect(_handle_lock_tree_exited, Object.CONNECT_ONE_SHOT)
	attach_callback.call(lock_instance)
	_set_interacting(true)
	return true

func capture_state() -> Dictionary:
	return {
		"unlocked": unlocked,
	}

func apply_state(state: Dictionary) -> void:
	unlocked = bool(state.get("unlocked", unlocked))

func _apply_code_value(lock_instance: Node) -> void:
	if "code_value" in lock_instance:
		lock_instance.code_value = access_code
	elif "target_code" in lock_instance:
		lock_instance.target_code = access_code

func _handle_unlock_success() -> void:
	unlocked = true
	_set_interacting(false)
	if _on_unlock_success.is_valid():
		_on_unlock_success.call()

func _handle_lock_tree_exited() -> void:
	var was_unlocked := unlocked
	_active_lock = null
	_set_interacting(false)
	if not was_unlocked and _on_unlock_failed_exit.is_valid():
		_on_unlock_failed_exit.call()

func _set_interacting(value: bool) -> void:
	if _on_interacting_changed.is_valid():
		_on_interacting_changed.call(value)
