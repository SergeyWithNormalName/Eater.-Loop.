extends RefCounted
class_name GamepadHighlighter

const ACTIVE_MODULATE := Color(1.0, 0.95, 0.62, 1.0)
const SELECTED_MODULATE := Color(0.72, 1.0, 0.72, 1.0)
const DIM_MODULATE := Color(0.82, 0.82, 0.82, 1.0)

var _original_modulates: Dictionary = {}
var _touched_items: Array[CanvasItem] = []

func clear() -> void:
	for item in _touched_items:
		if item == null or not is_instance_valid(item):
			continue
		var id := item.get_instance_id()
		if not _original_modulates.has(id):
			continue
		item.modulate = _original_modulates[id]
	_touched_items.clear()
	_original_modulates.clear()

func apply_visuals(active: Node, selected: Node = null, dim_nodes: Array = []) -> void:
	clear()
	for node in dim_nodes:
		_apply_modulate(node, DIM_MODULATE)
	if selected != null:
		_apply_modulate(selected, SELECTED_MODULATE)
	if active != null:
		_apply_modulate(active, ACTIVE_MODULATE)

func _apply_modulate(node: Node, color: Color) -> void:
	if not node is CanvasItem:
		return
	var item := node as CanvasItem
	if item == null or not is_instance_valid(item):
		return
	var id := item.get_instance_id()
	if not _original_modulates.has(id):
		_original_modulates[id] = item.modulate
		_touched_items.append(item)
	item.modulate = color
