extends "res://levels/cycles/level.gd"

const BASEMENT_LOCAL_BOUNDS := Rect2(6050.0, -320.0, 9150.0, 900.0)
const BASEMENT_DARKNESS_COLOR := Color(0.007843138, 0.007843138, 0.011764706, 1.0)
const TO202_DEFAULT_TARGET := NodePath("../../../202/InteractableObjects/Door(In202)")
const TO202_BEDROOM_TARGET := NodePath("../../../../Bedroom/InteractableObjects/Door(InBedroom)")
const CYCLE_START_SUBTITLE := "Как же темно.. наверно, генератор сдох"

var _darkness_node: CanvasModulate = null
var _player_node: Node2D = null
var _basement_node: Node2D = null
var _default_darkness_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _is_player_in_basement: bool = false
var _generator_node: Node = null
var _fridge_node: Node = null
var _door_to_202_node: Node = null

func _ready() -> void:
	show_start_subtitle = true
	start_subtitle_text = CYCLE_START_SUBTITLE
	_generator_node = get_node_or_null("Generator")
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
	_generator_node = get_node_or_null("Generator")
	_fridge_node = get_node_or_null("6thLevel/604/InteractableObjects/Fridge")
	_door_to_202_node = get_node_or_null("2thLevel/2thHall/InteractableObjects/Door(To202)")

	if _generator_node != null and _fridge_node != null:
		_fridge_node.set("dependency_object", _generator_node)
		_fridge_node.set("locked_message", "Snachala zapusti generator.")
		if _fridge_node.has_method("_setup_dependency_listener"):
			_fridge_node.call("_setup_dependency_listener")
		if _fridge_node.has_method("_refresh_prompt_state"):
			_fridge_node.call("_refresh_prompt_state")

		var on_generator_finished := Callable(self, "_on_generator_finished")
		if _generator_node.has_signal("interaction_finished") and not _generator_node.is_connected("interaction_finished", on_generator_finished):
			_generator_node.connect("interaction_finished", on_generator_finished)
		_apply_fridge_generator_state()

	if GameState != null and GameState.has_signal("fridge_interacted_changed"):
		var on_fridge_interacted := Callable(self, "_on_fridge_interacted_changed")
		if not GameState.is_connected("fridge_interacted_changed", on_fridge_interacted):
			GameState.connect("fridge_interacted_changed", on_fridge_interacted)
	_update_to202_target()

func should_show_start_subtitle() -> bool:
	if _generator_node == null:
		_generator_node = get_node_or_null("Generator")
	return not _is_generator_completed()

func _is_generator_completed() -> bool:
	if _generator_node == null:
		return false
	return bool(_generator_node.get("is_completed"))

func _apply_fridge_generator_state() -> void:
	if _fridge_node == null:
		return
	var generator_completed := _is_generator_completed()

	var fridge_sprite := _fridge_node.get_node_or_null("Sprite2D") as Sprite2D
	var locked_sprite := _fridge_node.get("locked_sprite") as Texture2D
	var available_sprite := _fridge_node.get("available_sprite") as Texture2D
	if fridge_sprite != null:
		if generator_completed and available_sprite != null:
			fridge_sprite.texture = available_sprite
		elif not generator_completed and locked_sprite != null:
			fridge_sprite.texture = locked_sprite

	var light_primary := _fridge_node.get_node_or_null("PointLight2D") as CanvasItem
	var light_secondary := _fridge_node.get_node_or_null("PointLight2D2") as CanvasItem
	if light_primary != null:
		light_primary.visible = generator_completed
	if light_secondary != null:
		light_secondary.visible = generator_completed

	var noise_player := _fridge_node.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
	if noise_player != null:
		noise_player.autoplay = false
		if generator_completed:
			if not noise_player.playing:
				noise_player.play()
		elif noise_player.playing:
			noise_player.stop()

func _on_generator_finished() -> void:
	_apply_fridge_generator_state()

func _on_fridge_interacted_changed() -> void:
	_update_to202_target()

func on_fed_andrey() -> void:
	_update_to202_target()

func _update_to202_target() -> void:
	if _door_to_202_node == null:
		return
	var should_open_bedroom := GameState != null and bool(GameState.ate_this_cycle)
	_door_to_202_node.set("target_marker", TO202_BEDROOM_TARGET if should_open_bedroom else TO202_DEFAULT_TARGET)
