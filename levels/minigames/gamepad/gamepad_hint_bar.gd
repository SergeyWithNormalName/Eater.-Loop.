extends RefCounted
class_name GamepadHintBar

const BAR_NAME := "__GamepadHintBar"

var _owner: Node = null
var _root: Control = null
var _label: Label = null
var _has_hints: bool = false
var _hint_mode_enabled: bool = false

func attach(owner: Node) -> void:
	clear()
	if owner == null:
		return
	var host := _resolve_host(owner)
	if host == null:
		return
	_owner = owner
	_root = Control.new()
	_root.name = BAR_NAME
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.anchor_left = 0.0
	margin.anchor_top = 1.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_left = 20.0
	margin.offset_top = -68.0
	margin.offset_right = -20.0
	margin.offset_bottom = -12.0
	_root.add_child(margin)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.72)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.3, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9, 1.0))
	_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(_label)

	host.add_child(_root)

func clear() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_label = null
	_owner = null
	_has_hints = false
	_hint_mode_enabled = false

func set_hints(hints: Dictionary) -> void:
	if _label == null or not is_instance_valid(_label):
		return
	var parts: Array[String] = []
	_append_hint(parts, hints, "confirm", "A")
	_append_hint(parts, hints, "cancel", "B")
	_append_hint(parts, hints, "secondary", "X")
	_append_hint(parts, hints, "tab_left", "LB")
	_append_hint(parts, hints, "tab_right", "RB")
	_label.text = "   ".join(parts)
	_has_hints = not parts.is_empty()
	_update_visibility()

func set_hint_mode(enabled: bool) -> void:
	_hint_mode_enabled = enabled
	_update_visibility()

func _update_visibility() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_root.visible = _hint_mode_enabled and _has_hints

func _append_hint(parts: Array[String], hints: Dictionary, key: String, button_name: String) -> void:
	if not hints.has(key):
		return
	var text := String(hints.get(key, "")).strip_edges()
	if text == "":
		return
	parts.append("%s: %s" % [button_name, text])

func _resolve_host(owner: Node) -> Node:
	if owner is CanvasLayer:
		return owner
	if owner is Control:
		return owner
	if owner.get_tree() == null:
		return owner
	if owner.get_tree().current_scene != null:
		return owner.get_tree().current_scene
	return owner.get_tree().root
