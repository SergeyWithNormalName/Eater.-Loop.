extends "res://levels/cycles/level.gd"

const BASEMENT_LOCAL_BOUNDS := Rect2(6050.0, -320.0, 9150.0, 900.0)
const BASEMENT_DARKNESS_COLOR := Color(0.007843138, 0.007843138, 0.011764706, 1.0)
const TO202_DEFAULT_TARGET := NodePath("../../../202/InteractableObjects/Door(In202)")
const TO202_BEDROOM_TARGET := NodePath("../../../../Bedroom/InteractableObjects/Door(InBedroom)")
const CYCLE_START_SUBTITLE := "Как же темно.. наверно, генератор сдох"
const FRIDGE_LOCKED_MESSAGE_RU := "Сначала запусти генератор."
const FRIDGE_LOCKED_MESSAGE_EN := "Start the generator first."

var _darkness_node: CanvasModulate = null
var _player_node: Node2D = null
var _basement_node: Node2D = null
var _default_darkness_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _is_player_in_basement: bool = false
var _generator_node: InteractiveObject = null
var _fridge_node: Node = null
var _door_to_202_node: Node = null

func _ready() -> void:
	show_start_subtitle = true
	start_subtitle_text = CYCLE_START_SUBTITLE
	_generator_node = get_node_or_null("Generator") as InteractiveObject
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
	_generator_node = get_node_or_null("Generator") as InteractiveObject
	_fridge_node = get_node_or_null("6thLevel/604/InteractableObjects/Fridge")
	_door_to_202_node = get_node_or_null("2thLevel/2thHall/InteractableObjects/Door(To202)")

	if _generator_node != null and _fridge_node != null and _fridge_node.has_method("set_dependency_object"):
		_fridge_node.call("set_dependency_object", _generator_node)
		_update_fridge_locked_message()
		if _fridge_node.has_method("refresh_visual_state"):
			_fridge_node.call("refresh_visual_state")

	if SettingsManager != null and SettingsManager.has_signal("language_changed"):
		var on_language_changed := Callable(self, "_on_language_changed")
		if not SettingsManager.language_changed.is_connected(on_language_changed):
			SettingsManager.language_changed.connect(on_language_changed)

	if CycleState != null and CycleState.has_signal("fridge_interacted_changed"):
		var on_fridge_interacted := Callable(self, "_on_fridge_interacted_changed")
		if not CycleState.is_connected("fridge_interacted_changed", on_fridge_interacted):
			CycleState.connect("fridge_interacted_changed", on_fridge_interacted)
	if CycleState != null and CycleState.has_signal("ate_this_cycle_changed"):
		var on_ate_changed := Callable(self, "_on_ate_this_cycle_changed")
		if not CycleState.is_connected("ate_this_cycle_changed", on_ate_changed):
			CycleState.connect("ate_this_cycle_changed", on_ate_changed)
	_update_to202_target()

func should_show_start_subtitle() -> bool:
	if _generator_node == null:
		_generator_node = get_node_or_null("Generator") as InteractiveObject
	return not _is_generator_completed()

func _is_generator_completed() -> bool:
	if _generator_node == null:
		return false
	return bool(_generator_node.is_completed)

func _on_fridge_interacted_changed() -> void:
	_update_to202_target()

func _on_ate_this_cycle_changed(_value: bool) -> void:
	_update_to202_target()

func _on_language_changed(_language: String) -> void:
	_update_fridge_locked_message()

func _update_to202_target() -> void:
	if _door_to_202_node == null:
		return
	var should_open_bedroom := CycleState != null and bool(CycleState.has_eaten_this_cycle())
	if _door_to_202_node.has_method("set_target_marker_path"):
		_door_to_202_node.call("set_target_marker_path", TO202_BEDROOM_TARGET if should_open_bedroom else TO202_DEFAULT_TARGET)

func _update_fridge_locked_message() -> void:
	if _fridge_node == null:
		return
	var message := FRIDGE_LOCKED_MESSAGE_RU if _is_russian_language() else FRIDGE_LOCKED_MESSAGE_EN
	_fridge_node.set("locked_message", message)

func _is_russian_language() -> bool:
	if SettingsManager != null and SettingsManager.has_method("get_language"):
		return String(SettingsManager.get_language()) == "ru"
	return TranslationServer.get_locale().to_lower().begins_with("ru")
