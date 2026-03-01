extends "res://levels/cycles/level.gd"

const BASEMENT_LOCAL_BOUNDS := Rect2(6050.0, -320.0, 9150.0, 900.0)
const BASEMENT_DARKNESS_COLOR := Color(0.045, 0.045, 0.055, 1.0)

var _darkness_node: CanvasModulate = null
var _player_node: Node2D = null
var _basement_node: Node2D = null
var _default_darkness_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _is_player_in_basement: bool = false

func _ready() -> void:
	super._ready()
	_darkness_node = get_node_or_null("Darkness") as CanvasModulate
	_player_node = get_node_or_null("Player") as Node2D
	_basement_node = get_node_or_null("Basement") as Node2D
	if _darkness_node != null:
		_default_darkness_color = _darkness_node.color
	_update_basement_darkness(true)
	call_deferred("_wire_level12_dependencies")

func _physics_process(_delta: float) -> void:
	_update_basement_darkness()

func _exit_tree() -> void:
	if _darkness_node != null:
		_darkness_node.color = _default_darkness_color

func _update_basement_darkness(force: bool = false) -> void:
	if _darkness_node == null or _player_node == null or _basement_node == null:
		return
	var local_player_pos := _basement_node.to_local(_player_node.global_position)
	var is_in_basement := BASEMENT_LOCAL_BOUNDS.has_point(local_player_pos)
	if not force and is_in_basement == _is_player_in_basement:
		return
	_is_player_in_basement = is_in_basement
	_darkness_node.color = BASEMENT_DARKNESS_COLOR if is_in_basement else _default_darkness_color

func _wire_level12_dependencies() -> void:
	var generator := get_node_or_null("Generator")
	var fridge := get_node_or_null("6thLevel/604/InteractableObjects/Fridge")
	if generator == null or fridge == null:
		return

	fridge.set("dependency_object", generator)
	fridge.set("locked_message", "Snachala zapusti generator.")

	if fridge.has_method("_setup_dependency_listener"):
		fridge.call("_setup_dependency_listener")
	if fridge.has_method("_refresh_prompt_state"):
		fridge.call("_refresh_prompt_state")
