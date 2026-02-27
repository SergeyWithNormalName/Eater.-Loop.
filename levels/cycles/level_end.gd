extends "res://levels/cycles/level.gd"

enum EndingBranch {
	NONE,
	LAPTOP,
	FRIDGE,
}

@export_group("Nodes")
@export var laptop_path: NodePath = NodePath("Hall/InteractableObjects/Laptop")
@export var fridge_path: NodePath = NodePath("Hall/InteractableObjects/Fridge")
@export var bed_path: NodePath = NodePath("Bedroom/InteractableObjects/Bed")

@export_group("Ending Scenes")
@export var bad_ending_scene: PackedScene

@export_group("Flow")
@export_range(0.0, 10.0, 0.1) var bad_ending_delay_after_fridge: float = 2.0
@export var laptop_sleep_prompt: String = "Надо лечь спать."

var _branch: EndingBranch = EndingBranch.NONE
var _ending_started: bool = false
var _bad_ending_queued: bool = false

var _laptop: InteractiveObject = null
var _fridge: InteractiveObject = null
var _bed: InteractiveObject = null

func _ready() -> void:
	super._ready()
	_resolve_nodes()
	_connect_level_flow()

func handle_custom_death_screen() -> bool:
	if _ending_started:
		return true
	if _branch != EndingBranch.FRIDGE:
		return false
	_start_bad_ending()
	return true

func on_fed_andrey() -> void:
	if _branch != EndingBranch.FRIDGE:
		return
	_queue_bad_ending_after_fridge()

func _resolve_nodes() -> void:
	_laptop = get_node_or_null(laptop_path) as InteractiveObject
	_fridge = get_node_or_null(fridge_path) as InteractiveObject
	_bed = get_node_or_null(bed_path) as InteractiveObject

func _connect_level_flow() -> void:
	if _laptop != null and not _laptop.interaction_requested.is_connected(_on_laptop_interaction_requested):
		_laptop.interaction_requested.connect(_on_laptop_interaction_requested)
	if _fridge != null and not _fridge.interaction_requested.is_connected(_on_fridge_interaction_requested):
		_fridge.interaction_requested.connect(_on_fridge_interaction_requested)
	if GameState != null and GameState.has_signal("lab_completed") and not GameState.lab_completed.is_connected(_on_lab_completed):
		GameState.lab_completed.connect(_on_lab_completed)
	if _fridge != null and _fridge.has_signal("ending_feeding_finished"):
		if not _fridge.is_connected("ending_feeding_finished", Callable(self, "_on_fridge_feeding_finished")):
			_fridge.connect("ending_feeding_finished", Callable(self, "_on_fridge_feeding_finished"))

func _on_laptop_interaction_requested(_player: Node = null) -> void:
	if _branch == EndingBranch.NONE:
		_choose_branch(EndingBranch.LAPTOP)

func _on_fridge_interaction_requested(_player: Node = null) -> void:
	if _branch == EndingBranch.NONE:
		_choose_branch(EndingBranch.FRIDGE)

func _choose_branch(branch: EndingBranch) -> void:
	_branch = branch
	match _branch:
		EndingBranch.LAPTOP:
			_set_fridge_enabled(false)
			if GameState != null and GameState.lab_done:
				_on_lab_completed()
		EndingBranch.FRIDGE:
			_set_laptop_enabled(false)

func _on_lab_completed() -> void:
	if _branch != EndingBranch.LAPTOP:
		return
	if GameState != null and GameState.has_method("mark_ate"):
		GameState.mark_ate()
	_set_bed_enabled(true)
	if UIMessage != null and laptop_sleep_prompt.strip_edges() != "":
		UIMessage.show_text(laptop_sleep_prompt)

func _on_fridge_feeding_finished() -> void:
	if _branch != EndingBranch.FRIDGE:
		return
	_queue_bad_ending_after_fridge()

func _queue_bad_ending_after_fridge() -> void:
	if _bad_ending_queued or _ending_started:
		return
	_bad_ending_queued = true
	if bad_ending_delay_after_fridge > 0.0:
		await get_tree().create_timer(bad_ending_delay_after_fridge).timeout
	if _ending_started:
		return
	_start_bad_ending()

func _start_bad_ending() -> void:
	if _ending_started:
		return
	_ending_started = true
	_set_laptop_enabled(false)
	_set_fridge_enabled(false)
	_set_bed_enabled(false)
	if bad_ending_scene == null:
		push_warning("LevelEnd: bad_ending_scene не назначена.")
		return
	if UIMessage != null and UIMessage.has_method("change_scene_with_fade"):
		await UIMessage.change_scene_with_fade(bad_ending_scene, 0.6, true)
		return
	get_tree().change_scene_to_packed(bad_ending_scene)

func _set_bed_enabled(enabled: bool) -> void:
	_set_object_enabled(_bed, enabled)

func _set_laptop_enabled(enabled: bool) -> void:
	_set_object_enabled(_laptop, enabled)
	if _laptop == null:
		return
	if _has_property(_laptop, &"is_enabled"):
		_laptop.set("is_enabled", enabled)

func _set_fridge_enabled(enabled: bool) -> void:
	_set_object_enabled(_fridge, enabled)
	_set_fridge_locked_visual(not enabled)

func _set_object_enabled(object: InteractiveObject, enabled: bool) -> void:
	if object == null:
		return
	object.handle_input = enabled
	object.set_prompts_enabled(enabled)

func _set_fridge_locked_visual(locked: bool) -> void:
	if _fridge == null:
		return
	var sprite_path := _read_node_path_property(_fridge, &"sprite_node")
	if not sprite_path.is_empty():
		var sprite := _fridge.get_node_or_null(sprite_path) as Sprite2D
		if sprite != null:
			var target_texture: Texture2D = _read_texture_property(_fridge, &"locked_sprite") if locked else _read_texture_property(_fridge, &"available_sprite")
			if target_texture != null:
				sprite.texture = target_texture
	_set_optional_canvas_item_visible(_fridge, &"available_light_node", not locked)
	_set_optional_canvas_item_visible(_fridge, &"available_light_node_secondary", not locked)
	if _fridge.has_method("_update_rocking_pivot"):
		_fridge.call("_update_rocking_pivot")

func _set_optional_canvas_item_visible(root: Node, property_name: StringName, visible_state: bool) -> void:
	if root == null:
		return
	var path := _read_node_path_property(root, property_name)
	if path.is_empty():
		return
	var node := root.get_node_or_null(path) as CanvasItem
	if node == null:
		return
	node.visible = visible_state

func _read_node_path_property(target: Object, property_name: StringName) -> NodePath:
	if not _has_property(target, property_name):
		return NodePath("")
	var value: Variant = target.get(String(property_name))
	if value is NodePath:
		return value
	return NodePath("")

func _read_texture_property(target: Object, property_name: StringName) -> Texture2D:
	if not _has_property(target, property_name):
		return null
	var value: Variant = target.get(String(property_name))
	if value is Texture2D:
		return value
	return null

func _has_property(target: Object, property_name: StringName) -> bool:
	if target == null:
		return false
	for entry in target.get_property_list():
		if StringName(entry.get("name", "")) == property_name:
			return true
	return false
