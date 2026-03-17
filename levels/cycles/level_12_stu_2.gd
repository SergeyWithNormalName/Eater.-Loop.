extends "res://levels/cycles/level.gd"

const SceneRuleRunnerScript = preload("res://levels/scene_rules/scene_rule_runner.gd")
const SceneRuleScript = preload("res://levels/scene_rules/scene_rule.gd")
const SetDependencyActionScript = preload("res://levels/scene_rules/set_dependency_action.gd")
const RefreshInteractionStateActionScript = preload("res://levels/scene_rules/refresh_interaction_state_action.gd")
const SetDoorTargetFromCycleStateActionScript = preload("res://levels/scene_rules/set_door_target_from_cycle_state_action.gd")

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
var _fridge_node: InteractiveObject = null

func _ready() -> void:
	show_start_subtitle = true
	start_subtitle_text = CYCLE_START_SUBTITLE
	super._ready()
	_darkness_node = get_node_or_null("Darkness") as CanvasModulate
	_player_node = get_node_or_null("Player") as Node2D
	_basement_node = get_node_or_null("Basement") as Node2D
	if _darkness_node != null:
		_default_darkness_color = _darkness_node.color
	_update_basement_darkness(true)
	_wire_level12_dependencies()

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
	_fridge_node = get_node_or_null("6thLevel/604/InteractableObjects/Fridge") as InteractiveObject
	var runner = SceneRuleRunnerScript.new()
	var dependency_rule = SceneRuleScript.new()
	dependency_rule.trigger_kind = SceneRuleScript.TriggerKind.READY
	var set_dependency = SetDependencyActionScript.new()
	set_dependency.target_path = NodePath("6thLevel/604/InteractableObjects/Fridge")
	set_dependency.dependency_path = NodePath("Generator")
	var refresh_fridge = RefreshInteractionStateActionScript.new()
	refresh_fridge.target_path = NodePath("6thLevel/604/InteractableObjects/Fridge")
	var set_target = SetDoorTargetFromCycleStateActionScript.new()
	set_target.door_path = NodePath("2thLevel/2thHall/InteractableObjects/Door(To202)")
	set_target.condition_kind = SetDoorTargetFromCycleStateActionScript.ConditionKind.ATE_THIS_CYCLE
	set_target.target_if_true = TO202_BEDROOM_TARGET
	set_target.target_if_false = TO202_DEFAULT_TARGET
	dependency_rule.actions = [set_dependency, refresh_fridge, set_target]
	var fridge_changed_rule = SceneRuleScript.new()
	fridge_changed_rule.trigger_kind = SceneRuleScript.TriggerKind.SIGNAL
	fridge_changed_rule.source_path = NodePath("/root/CycleState")
	fridge_changed_rule.signal_name = "fridge_interacted_changed"
	fridge_changed_rule.one_shot = false
	fridge_changed_rule.actions = [set_target]
	var ate_changed_rule = SceneRuleScript.new()
	ate_changed_rule.trigger_kind = SceneRuleScript.TriggerKind.SIGNAL
	ate_changed_rule.source_path = NodePath("/root/CycleState")
	ate_changed_rule.signal_name = "ate_this_cycle_changed"
	ate_changed_rule.one_shot = false
	ate_changed_rule.actions = [set_target]
	runner.rules = [dependency_rule, fridge_changed_rule, ate_changed_rule]
	add_child(runner)
	runner.run_actions(dependency_rule.actions, [])
	if SettingsManager != null and not SettingsManager.language_changed.is_connected(_on_language_changed):
		SettingsManager.language_changed.connect(_on_language_changed)
	_update_fridge_locked_message()

func should_show_start_subtitle() -> bool:
	var generator_node := get_node_or_null("Generator") as InteractiveObject
	return generator_node == null or not generator_node.is_completed

func _on_language_changed(_language: String) -> void:
	_update_fridge_locked_message()

func _update_fridge_locked_message() -> void:
	if _fridge_node == null:
		return
	_fridge_node.locked_message = FRIDGE_LOCKED_MESSAGE_RU if _is_russian_language() else FRIDGE_LOCKED_MESSAGE_EN
	_fridge_node.refresh_interaction_state()

func _is_russian_language() -> bool:
	if SettingsManager != null:
		return String(SettingsManager.get_language()) == "ru"
	return TranslationServer.get_locale().to_lower().begins_with("ru")
