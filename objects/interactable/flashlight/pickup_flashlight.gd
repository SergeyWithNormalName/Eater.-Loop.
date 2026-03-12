extends InteractiveObject

const ReactiveLightUtils = preload("res://global/reactive_light_utils.gd")

@export_group("Pickup")
@export var pickup_message: String = "Подобрал фонарик."
@export var already_collected_message: String = ""

@export_group("Light Settings")
@export var light_node: NodePath = NodePath("PointLight2D")
@export var light_range: float = 650.0
@export var light_fov_deg: float = 90.0
@export var beam_direction_local: Vector2 = Vector2.LEFT

var _light: PointLight2D = null

func _ready() -> void:
	super._ready()

	_light = get_node_or_null(light_node) as PointLight2D
	if not is_in_group("reactive_light_source"):
		add_to_group("reactive_light_source")
	if _should_despawn_immediately():
		call_deferred("queue_free")

func is_light_active() -> bool:
	return _light != null and _light.enabled

func is_point_lit(point: Vector2) -> bool:
	if not is_light_active():
		return false
	var origin := ReactiveLightUtils.resolve_light_origin(_light)
	var facing := _resolve_beam_direction()
	return ReactiveLightUtils.is_point_within_cone(origin, facing, point, light_range, light_fov_deg)

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
	_hide_prompt()
	if _light != null:
		_light.enabled = false
	set_interaction_enabled(false)
	visible = false
	call_deferred("queue_free")

func _resolve_beam_direction() -> Vector2:
	var local_direction := beam_direction_local
	if local_direction.length_squared() <= 0.000001:
		local_direction = Vector2.LEFT
	var facing := global_transform.basis_xform(local_direction.normalized())
	if facing.length_squared() <= 0.000001:
		return Vector2.LEFT
	return facing.normalized()

func _should_despawn_immediately() -> bool:
	if CycleState != null and CycleState.has_method("has_flashlight_for_current_cycle"):
		return bool(CycleState.has_flashlight_for_current_cycle())
	if GameState != null and GameState.has_method("is_flashlight_unlocked"):
		return bool(GameState.is_flashlight_unlocked())
	return false
