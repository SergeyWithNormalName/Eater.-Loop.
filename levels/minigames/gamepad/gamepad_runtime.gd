extends RefCounted
class_name GamepadRuntime

const GamepadSpatialNavClass = preload("res://levels/minigames/gamepad/gamepad_spatial_nav.gd")
const GamepadHighlighterClass = preload("res://levels/minigames/gamepad/gamepad_highlighter.gd")
const GamepadHintBarClass = preload("res://levels/minigames/gamepad/gamepad_hint_bar.gd")

const MODE_FOCUS := "focus"
const MODE_PICK_PLACE := "pick_place"

const SECTION_FOCUS := "focus"
const SECTION_SOURCE := "source"
const SECTION_TARGET := "target"

const DEFAULT_NAV_REPEAT_DELAY := 0.28
const DEFAULT_NAV_REPEAT_INTERVAL := 0.12

var _active_minigame: Node = null
var _scheme: Dictionary = {}
var _mode: String = MODE_FOCUS
var _section: String = SECTION_FOCUS

var _focus_nodes: Array[Node] = []
var _source_nodes: Array[Node] = []
var _target_nodes: Array[Node] = []

var _focus_selection: Node = null
var _source_selection: Node = null
var _target_selection: Node = null
var _selected_source: Node = null

var _nav = GamepadSpatialNavClass.new()
var _highlighter = GamepadHighlighterClass.new()
var _hint_bar = GamepadHintBarClass.new()

var _held_dir := Vector2.ZERO
var _held_elapsed := 0.0
var _repeat_accumulator := 0.0
var _nav_repeat_delay: float = DEFAULT_NAV_REPEAT_DELAY
var _nav_repeat_interval: float = DEFAULT_NAV_REPEAT_INTERVAL
var _show_gamepad_hints: bool = false
var _confirm_release_gate: bool = false

func start(minigame: Node, scheme: Dictionary) -> void:
	if minigame == null:
		return
	_active_minigame = minigame
	_apply_scheme(scheme)
	_hint_bar.attach(minigame)
	_show_gamepad_hints = false
	_hint_bar.set_hint_mode(false)
	_confirm_release_gate = _is_action_pressed("mg_confirm") or _is_action_pressed("ui_accept")
	_refresh_state(true)

func clear() -> void:
	_active_minigame = null
	_scheme.clear()
	_mode = MODE_FOCUS
	_section = SECTION_FOCUS
	_focus_nodes.clear()
	_source_nodes.clear()
	_target_nodes.clear()
	_focus_selection = null
	_source_selection = null
	_target_selection = null
	_selected_source = null
	_held_dir = Vector2.ZERO
	_held_elapsed = 0.0
	_repeat_accumulator = 0.0
	_nav_repeat_delay = DEFAULT_NAV_REPEAT_DELAY
	_nav_repeat_interval = DEFAULT_NAV_REPEAT_INTERVAL
	_show_gamepad_hints = false
	_confirm_release_gate = false
	_highlighter.clear()
	_hint_bar.clear()

func is_active_for(minigame: Node) -> bool:
	return _active_minigame != null and minigame == _active_minigame

func set_scheme(minigame: Node, scheme: Dictionary) -> void:
	if minigame == null:
		return
	if _active_minigame != minigame:
		return
	_apply_scheme(scheme)
	_refresh_state(true)

func clear_scheme(minigame: Node) -> void:
	if minigame == null:
		return
	if _active_minigame != minigame:
		return
	clear()

func process(delta: float) -> void:
	if _active_minigame == null:
		return
	if not is_instance_valid(_active_minigame):
		clear()
		return
	_refresh_state(false)
	_process_navigation_hold(delta)

func observe_input_device(event: InputEvent) -> void:
	if event == null:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_set_gamepad_hint_visibility(true)
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_gamepad_hint_visibility(false)
		return
	if event is InputEventKey:
		_set_gamepad_hint_visibility(false)

func handle_input(event: InputEvent) -> bool:
	if _active_minigame == null:
		return false
	if event == null:
		return false
	if event.is_echo():
		return false
	_update_confirm_release_gate(event)
	if _try_handle_navigation_input(event):
		return true
	if _is_confirm_pressed(event):
		_confirm()
		return true
	if _is_secondary_pressed(event):
		_secondary()
		return true
	if _is_tab_left_pressed(event):
		return _switch_section(-1)
	if _is_tab_right_pressed(event):
		return _switch_section(1)
	return false

func handle_cancel() -> bool:
	if _active_minigame == null:
		return false
	if _mode != MODE_PICK_PLACE:
		return false
	if _selected_source == null:
		return false
	var context := _build_context()
	_invoke_callback("on_cancel_pick", [_selected_source, context])
	_selected_source = null
	_section = SECTION_SOURCE
	_refresh_state(false)
	return true

func _apply_scheme(scheme: Dictionary) -> void:
	_scheme = scheme.duplicate(true)
	_mode = String(_scheme.get("mode", MODE_FOCUS))
	if _mode != MODE_PICK_PLACE:
		_mode = MODE_FOCUS
	_nav_repeat_delay = maxf(0.05, float(_scheme.get("nav_repeat_delay", DEFAULT_NAV_REPEAT_DELAY)))
	_nav_repeat_interval = maxf(0.05, float(_scheme.get("nav_repeat_interval", DEFAULT_NAV_REPEAT_INTERVAL)))
	_section = SECTION_SOURCE if _mode == MODE_PICK_PLACE else SECTION_FOCUS
	_selected_source = null
	_focus_selection = null
	_source_selection = null
	_target_selection = null

func _refresh_state(force_initial: bool) -> void:
	_focus_selection = _as_valid_node(_focus_selection)
	_source_selection = _as_valid_node(_source_selection)
	_target_selection = _as_valid_node(_target_selection)
	_selected_source = _as_valid_node(_selected_source)
	if _mode == MODE_FOCUS:
		_focus_nodes = _resolve_nodes("focus_nodes", "focus_provider")
		_focus_selection = _resolve_selection(_focus_selection, _focus_nodes, force_initial)
		_section = SECTION_FOCUS
	else:
		_source_nodes = _resolve_nodes("source_nodes", "source_provider")
		_target_nodes = _resolve_nodes("target_nodes", "target_provider")
		_source_selection = _resolve_selection(_source_selection, _source_nodes, force_initial)
		_target_selection = _resolve_selection(_target_selection, _target_nodes, force_initial)
		if _selected_source != null and not _source_nodes.has(_selected_source):
			_selected_source = null
		if _section == SECTION_TARGET and (_selected_source == null or _target_nodes.is_empty()):
			_section = SECTION_SOURCE
		if _section == SECTION_SOURCE and _source_selection == null and not _source_nodes.is_empty():
			_source_selection = _nav.choose_initial(_source_nodes)
		if _section == SECTION_TARGET and _target_selection == null and not _target_nodes.is_empty():
			_target_selection = _nav.choose_initial(_target_nodes)
	_apply_visual_state()

func _resolve_selection(current: Variant, nodes: Array[Node], force_initial: bool) -> Node:
	var current_node := _as_valid_node(current)
	if nodes.is_empty():
		return null
	if current_node != null and nodes.has(current_node):
		return current_node
	if force_initial or current_node == null:
		return _nav.choose_initial(nodes)
	return nodes[0]

func _resolve_nodes(nodes_key: String, provider_key: String) -> Array[Node]:
	var raw_nodes: Variant = _scheme.get(nodes_key, [])
	var provider: Variant = _scheme.get(provider_key, Callable())
	if provider is Callable:
		var callable_provider := provider as Callable
		if callable_provider.is_valid():
			raw_nodes = callable_provider.call()
	return _coerce_nodes(raw_nodes)

func _coerce_nodes(raw_nodes: Variant) -> Array[Node]:
	var result: Array[Node] = []
	if raw_nodes is Array:
		for entry in raw_nodes:
			var node := _resolve_node(entry)
			if node == null:
				continue
			if result.has(node):
				continue
			if not _is_node_focusable(node):
				continue
			result.append(node)
	return result

func _resolve_node(entry: Variant) -> Node:
	if entry is Node:
		return entry
	if entry is NodePath:
		if _active_minigame == null:
			return null
		return _active_minigame.get_node_or_null(entry)
	if entry is WeakRef:
		var weak := entry as WeakRef
		var ref = weak.get_ref()
		if ref is Node:
			return ref
	return null

func _is_node_focusable(node: Node) -> bool:
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

func _try_handle_navigation_input(event: InputEvent) -> bool:
	var dir := _direction_from_event(event)
	if dir == Vector2.ZERO:
		return false
	_step_navigation(dir)
	_prime_navigation_hold(dir)
	return true

func _direction_from_event(event: InputEvent) -> Vector2:
	if _is_nav_action_pressed(event, "mg_nav_left", "ui_left"):
		return Vector2.LEFT
	if _is_nav_action_pressed(event, "mg_nav_right", "ui_right"):
		return Vector2.RIGHT
	if _is_nav_action_pressed(event, "mg_nav_up", "ui_up"):
		return Vector2.UP
	if _is_nav_action_pressed(event, "mg_nav_down", "ui_down"):
		return Vector2.DOWN
	return Vector2.ZERO

func _is_nav_action_pressed(event: InputEvent, primary: StringName, fallback: StringName) -> bool:
	return event.is_action_pressed(primary) or event.is_action_pressed(fallback)

func _step_navigation(direction: Vector2) -> void:
	_refresh_state(false)
	var nodes := _get_active_section_nodes()
	if nodes.is_empty():
		return
	var current := _get_active_selection()
	var next: Node = _nav.find_next(current, nodes, direction, true)
	if next == null:
		return
	_set_active_selection(next)
	_apply_visual_state()

func _process_navigation_hold(delta: float) -> void:
	var direction := _read_pressed_direction()
	if direction == Vector2.ZERO:
		_held_dir = Vector2.ZERO
		_held_elapsed = 0.0
		_repeat_accumulator = 0.0
		return
	if direction != _held_dir:
		_prime_navigation_hold(direction)
		return
	_held_elapsed += delta
	if _held_elapsed < _nav_repeat_delay:
		return
	_repeat_accumulator += delta
	while _repeat_accumulator >= _nav_repeat_interval:
		_repeat_accumulator -= _nav_repeat_interval
		_step_navigation(direction)

func _prime_navigation_hold(direction: Vector2) -> void:
	_held_dir = direction
	_held_elapsed = 0.0
	_repeat_accumulator = 0.0

func _read_pressed_direction() -> Vector2:
	var x := 0
	var y := 0
	if _is_action_pressed("mg_nav_left") or _is_action_pressed("ui_left"):
		x -= 1
	if _is_action_pressed("mg_nav_right") or _is_action_pressed("ui_right"):
		x += 1
	if _is_action_pressed("mg_nav_up") or _is_action_pressed("ui_up"):
		y -= 1
	if _is_action_pressed("mg_nav_down") or _is_action_pressed("ui_down"):
		y += 1
	if x != 0 and y != 0:
		y = 0
	if x == 0 and y == 0:
		return Vector2.ZERO
	return Vector2(x, y)

func _is_action_pressed(action_name: StringName) -> bool:
	if not InputMap.has_action(action_name):
		return false
	return Input.is_action_pressed(action_name)

func _is_confirm_pressed(event: InputEvent) -> bool:
	var pressed := event.is_action_pressed("mg_confirm") or event.is_action_pressed("ui_accept")
	if not pressed:
		return false
	if _confirm_release_gate:
		return false
	return true

func _is_secondary_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("mg_secondary")

func _is_tab_left_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("mg_tab_left")

func _is_tab_right_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("mg_tab_right")

func _confirm() -> void:
	_refresh_state(false)
	if _mode == MODE_PICK_PLACE:
		_confirm_pick_place()
		return
	var active := _get_active_selection()
	if active == null:
		return
	var context := _build_context()
	if _invoke_callback_consumed("on_confirm", [active, context]):
		return
	_default_confirm(active)
	_apply_visual_state()

func _confirm_pick_place() -> void:
	var active := _get_active_selection()
	if active == null:
		return
	var context := _build_context()
	if _selected_source == null:
		_selected_source = active
		_invoke_callback("on_pick", [_selected_source, context])
		if _target_nodes.is_empty():
			_selected_source = null
			_section = SECTION_SOURCE
		else:
			_section = SECTION_TARGET
			_target_selection = _resolve_selection(_target_selection, _target_nodes, true)
		_apply_visual_state()
		return
	if _section != SECTION_TARGET:
		_selected_source = active
		_invoke_callback("on_pick", [_selected_source, context])
		_section = SECTION_TARGET
		_target_selection = _resolve_selection(_target_selection, _target_nodes, true)
		_apply_visual_state()
		return
	var success := true
	if _has_callback("on_place"):
		var result = _call_callback("on_place", [_selected_source, active, context])
		if typeof(result) == TYPE_BOOL:
			success = bool(result)
	if success:
		_invoke_callback("on_placed", [_selected_source, active, context])
		_selected_source = null
		_section = SECTION_SOURCE
	_apply_visual_state()

func _secondary() -> void:
	_refresh_state(false)
	var active := _get_active_selection()
	if active == null:
		return
	var context := _build_context()
	if _invoke_callback_consumed("on_secondary", [active, context]):
		_apply_visual_state()
		return
	if active.has_method("on_gamepad_secondary"):
		active.call("on_gamepad_secondary")
	_apply_visual_state()

func _switch_section(delta: int) -> bool:
	if _mode != MODE_PICK_PLACE:
		return false
	if _selected_source == null:
		return false
	if _source_nodes.is_empty() or _target_nodes.is_empty():
		return false
	if delta == 0:
		return false
	_section = SECTION_SOURCE if _section == SECTION_TARGET else SECTION_TARGET
	_apply_visual_state()
	return true

func _default_confirm(active: Node) -> void:
	if active is BaseButton:
		(active as BaseButton).emit_signal("pressed")
		return
	if active.has_method("on_gamepad_confirm"):
		active.call("on_gamepad_confirm")

func _get_active_section_nodes() -> Array[Node]:
	if _mode == MODE_PICK_PLACE:
		return _target_nodes if _section == SECTION_TARGET else _source_nodes
	return _focus_nodes

func _get_active_selection() -> Node:
	if _mode == MODE_PICK_PLACE:
		return _target_selection if _section == SECTION_TARGET else _source_selection
	return _focus_selection

func _set_active_selection(node: Node) -> void:
	if _mode == MODE_PICK_PLACE:
		if _section == SECTION_TARGET:
			_target_selection = node
		else:
			_source_selection = node
		return
	_focus_selection = node

func _apply_visual_state() -> void:
	var active := _get_active_selection()
	if active is Control:
		var control := active as Control
		if control.focus_mode != Control.FOCUS_NONE and control.is_inside_tree():
			control.grab_focus()
	var dim_nodes: Array[Node] = []
	if _mode == MODE_PICK_PLACE:
		if _section == SECTION_TARGET:
			for source in _source_nodes:
				if source == _selected_source:
					continue
				dim_nodes.append(source)
		else:
			dim_nodes.append_array(_target_nodes)
	if _is_highlighter_enabled():
		_highlighter.apply_visuals(active, _selected_source, dim_nodes)
	else:
		_highlighter.clear()
	if _show_gamepad_hints:
		_hint_bar.set_hints(_build_hints())
	else:
		_hint_bar.set_hints({})
	_invoke_callback("on_focus_changed", [active, _build_context()])

func _build_hints() -> Dictionary:
	var hints: Dictionary = {}
	var custom_hints: Variant = _scheme.get("hints", {})
	if custom_hints is Dictionary:
		hints = (custom_hints as Dictionary).duplicate(true)
	if _mode == MODE_PICK_PLACE:
		if not hints.has("confirm"):
			hints["confirm"] = "Поместить" if _selected_source != null else "Выбрать"
		if _selected_source != null:
			hints["cancel"] = "Отменить выбор"
			if _source_nodes.size() > 0 and _target_nodes.size() > 0:
				if not hints.has("tab_left"):
					hints["tab_left"] = "Секция"
				if not hints.has("tab_right"):
					hints["tab_right"] = "Секция"
		elif not hints.has("cancel"):
			hints["cancel"] = "Выход"
	else:
		if not hints.has("confirm"):
			hints["confirm"] = "Подтвердить"
		if not hints.has("cancel"):
			hints["cancel"] = "Выход"
	if not _has_callback("on_secondary") and not hints.has("secondary"):
		hints.erase("secondary")
	return hints

func _build_context() -> Dictionary:
	return {
		"mode": _mode,
		"section": _section,
		"selected_source": _selected_source,
		"active_node": _get_active_selection(),
		"focus_nodes": _focus_nodes,
		"source_nodes": _source_nodes,
		"target_nodes": _target_nodes
	}

func _has_callback(name: String) -> bool:
	if not _scheme.has(name):
		return false
	var callback: Variant = _scheme.get(name, Callable())
	return callback is Callable and (callback as Callable).is_valid()

func _invoke_callback(name: String, args: Array = []) -> bool:
	if not _has_callback(name):
		return false
	_call_callback(name, args)
	return true

func _invoke_callback_consumed(name: String, args: Array = []) -> bool:
	if not _has_callback(name):
		return false
	var result = _call_callback(name, args)
	if typeof(result) == TYPE_BOOL:
		return bool(result)
	return true

func _call_callback(name: String, args: Array = []) -> Variant:
	var callback := _scheme.get(name, Callable()) as Callable
	return callback.callv(args)

func _set_gamepad_hint_visibility(visible: bool) -> void:
	if _show_gamepad_hints == visible:
		return
	_show_gamepad_hints = visible
	_hint_bar.set_hint_mode(visible)

func _as_valid_node(value: Variant) -> Node:
	if not (value is Node):
		return null
	var node := value as Node
	if node == null:
		return null
	if not is_instance_valid(node):
		return null
	if node.is_queued_for_deletion():
		return null
	return node

func _is_highlighter_enabled() -> bool:
	return bool(_scheme.get("enable_highlighter", true))

func _update_confirm_release_gate(event: InputEvent) -> void:
	if not _confirm_release_gate:
		return
	if event != null and (event.is_action_released("mg_confirm") or event.is_action_released("ui_accept")):
		_confirm_release_gate = false
		return
	if _is_action_pressed("mg_confirm") or _is_action_pressed("ui_accept"):
		return
	_confirm_release_gate = false
