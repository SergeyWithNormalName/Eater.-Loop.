extends RefCounted
class_name GamepadSpatialNav

const DEFAULT_FOCUS_SIZE := Vector2(64.0, 64.0)

func choose_initial(candidates: Array) -> Node:
	var valid := _filter_candidates(candidates)
	if valid.is_empty():
		return null
	var best := valid[0]
	var best_rect := get_focus_rect(best)
	for candidate in valid:
		var rect := get_focus_rect(candidate)
		if rect.position.y < best_rect.position.y:
			best = candidate
			best_rect = rect
			continue
		if is_equal_approx(rect.position.y, best_rect.position.y) and rect.position.x < best_rect.position.x:
			best = candidate
			best_rect = rect
	return best

func find_next(current: Node, candidates: Array, direction: Vector2, allow_wrap: bool = true) -> Node:
	var valid := _filter_candidates(candidates)
	if valid.is_empty():
		return null
	if current == null or not valid.has(current):
		return choose_initial(valid)
	if direction == Vector2.ZERO:
		return current
	var dir := direction.normalized()

	var current_rect := get_focus_rect(current)
	var current_center := current_rect.get_center()

	var best_node: Node = null
	var best_score := INF
	for candidate in valid:
		if candidate == current:
			continue
		var rect := get_focus_rect(candidate)
		var to_center := rect.get_center() - current_center
		if to_center == Vector2.ZERO:
			continue
		var dot := to_center.normalized().dot(dir)
		if dot <= 0.1:
			continue
		var projection: float = to_center.dot(dir)
		var lateral: float = absf(to_center.dot(Vector2(-dir.y, dir.x)))
		var score: float = projection + lateral * 0.35 - dot * 20.0
		if score < best_score:
			best_score = score
			best_node = candidate

	if best_node != null:
		return best_node
	if not allow_wrap:
		return current
	return _find_wrap_candidate(current_center, valid, dir)

func get_focus_rect(node: Node) -> Rect2:
	if node == null:
		return Rect2(Vector2.ZERO, DEFAULT_FOCUS_SIZE)
	if node.has_method("get_gamepad_focus_rect"):
		var custom_rect = node.call("get_gamepad_focus_rect")
		if custom_rect is Rect2:
			return custom_rect
	if node is Control:
		var control := node as Control
		var rect := control.get_global_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			return rect
		var control_size := control.size
		if control_size == Vector2.ZERO:
			control_size = control.get_combined_minimum_size()
		if control_size == Vector2.ZERO:
			control_size = DEFAULT_FOCUS_SIZE
		return Rect2(control.global_position, control_size)
	if node is CanvasItem:
		var item := node as CanvasItem
		var focus_size: Variant = item.get_meta("gamepad_focus_size", DEFAULT_FOCUS_SIZE)
		if not focus_size is Vector2:
			focus_size = DEFAULT_FOCUS_SIZE
		var center: Vector2 = item.global_position
		var cast_size: Vector2 = focus_size as Vector2
		return Rect2(center - (cast_size * 0.5), cast_size)
	return Rect2(Vector2.ZERO, DEFAULT_FOCUS_SIZE)

func _filter_candidates(candidates: Array) -> Array[Node]:
	var valid: Array[Node] = []
	for candidate in candidates:
		if not candidate is Node:
			continue
		var node := candidate as Node
		if not _is_focusable(node):
			continue
		valid.append(node)
	return valid

func _is_focusable(node: Node) -> bool:
	if node == null:
		return false
	if not is_instance_valid(node):
		return false
	if node.is_queued_for_deletion():
		return false
	if node.has_method("is_gamepad_focusable"):
		return bool(node.call("is_gamepad_focusable"))
	if node is CanvasItem:
		var item := node as CanvasItem
		if not item.visible:
			return false
	if node is BaseButton:
		var button := node as BaseButton
		if button.disabled:
			return false
	return true

func _find_wrap_candidate(current_center: Vector2, valid: Array[Node], direction: Vector2) -> Node:
	var best: Node = null
	var best_projection := INF
	var best_lateral := INF
	for candidate in valid:
		var rect := get_focus_rect(candidate)
		var to_center := rect.get_center() - current_center
		var projection := to_center.dot(direction)
		var lateral: float = abs(to_center.dot(Vector2(-direction.y, direction.x)))
		if projection < best_projection:
			best_projection = projection
			best_lateral = lateral
			best = candidate
			continue
		if is_equal_approx(projection, best_projection) and lateral < best_lateral:
			best_projection = projection
			best_lateral = lateral
			best = candidate
	return best
