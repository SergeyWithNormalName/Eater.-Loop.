extends InteractiveObject

const PICKUP_FLASHLIGHT_GROUP := &"pickup_flashlight"

@export_group("Pickup")
@export var pickup_message: String = "Подобрал фонарик."
@export var already_collected_message: String = ""

@export_group("Light Settings")
@export var light_node: NodePath = NodePath("PointLight2D")
@export var light_range: float = 650.0
@export var light_fov_deg: float = 90.0
@export_group("Prompt Settings")
@export var prompt_anchor_node: NodePath = NodePath("Sprite2D")

var _light: PointLight2D = null
var _prompt_anchor: Node2D = null

func _ready() -> void:
	super._ready()

	_light = get_node_or_null(light_node) as PointLight2D
	_prompt_anchor = get_node_or_null(prompt_anchor_node) as Node2D
	if not is_in_group(PICKUP_FLASHLIGHT_GROUP):
		add_to_group(PICKUP_FLASHLIGHT_GROUP)
	if not is_in_group(GroupNames.REACTIVE_LIGHT_SOURCE):
		add_to_group(GroupNames.REACTIVE_LIGHT_SOURCE)
	if _should_despawn_immediately():
		call_deferred("queue_free")

func is_light_active() -> bool:
	return _light != null and _light.enabled

func is_point_lit(point: Vector2) -> bool:
	if not is_light_active():
		return false
	var origin := ReactiveLightUtils.resolve_light_origin(_light)
	var facing := ReactiveLightUtils.facing_from_light(_light)
	return ReactiveLightUtils.is_point_within_cone(origin, facing, point, light_range, light_fov_deg)

func get_prompt_world_position() -> Vector2:
	if _prompt_anchor != null:
		return _prompt_anchor.to_global(prompt_offset)
	return super.get_prompt_world_position()

func _on_interact() -> void:
	if CycleState == null or not CycleState.has_method("collect_flashlight_for_cycle"):
		return
	if _should_despawn_immediately():
		if already_collected_message.strip_edges() != "" and UIMessage != null:
			UIMessage.show_notification(already_collected_message)
		call_deferred("queue_free")
		return
	CycleState.collect_flashlight_for_cycle()
	if UIMessage != null and pickup_message.strip_edges() != "":
		UIMessage.show_notification(tr(pickup_message))
	_despawn_all_pickups_in_location()

func _should_despawn_immediately() -> bool:
	if CycleState != null and CycleState.has_method("has_flashlight_for_current_cycle"):
		return bool(CycleState.has_flashlight_for_current_cycle())
	if GameState != null and GameState.has_method("is_flashlight_unlocked"):
		return bool(GameState.is_flashlight_unlocked())
	return false

func _despawn_all_pickups_in_location() -> void:
	var tree := get_tree()
	if tree == null:
		_despawn_pickup()
		return
	var branch_root := _get_location_branch_root()
	for pickup in tree.get_nodes_in_group(PICKUP_FLASHLIGHT_GROUP):
		if not (pickup is Node):
			continue
		if pickup == null or not is_instance_valid(pickup):
			continue
		if branch_root != null and _get_branch_root_for_node(pickup) != branch_root:
			continue
		if pickup.has_method("_despawn_pickup"):
			pickup.call("_despawn_pickup")

func _despawn_pickup() -> void:
	_hide_prompt()
	if _light != null:
		_light.enabled = false
	set_interaction_enabled(false)
	visible = false
	call_deferred("queue_free")

func _get_location_branch_root() -> Node:
	return _get_branch_root_for_node(self)

func _get_branch_root_for_node(node: Node) -> Node:
	if node == null:
		return null
	var tree := node.get_tree()
	if tree == null:
		return node
	var branch_root: Node = node
	while branch_root.get_parent() != null and branch_root.get_parent() != tree.root:
		branch_root = branch_root.get_parent()
	return branch_root
