extends "res://enemies/enemy.gd"

const ReactiveLightUtils = preload("res://global/reactive_light_utils.gd")

@export_group("Flashlight Detection")
## Максимальная дальность влияния фонарика.
@export var flashlight_range: float = 650.0
## Угол конуса фонарика в градусах.
@export var flashlight_fov_deg: float = 90.0
## Учитывать только включенный фонарик.
@export var flashlight_requires_enabled: bool = true

var _cached_flashlight: PointLight2D = null

func _get_flashlight() -> PointLight2D:
	if _cached_flashlight != null and is_instance_valid(_cached_flashlight):
		return _cached_flashlight

	var player := _player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null

	if player.has_node("Pivot/PointLight2D"):
		_cached_flashlight = player.get_node("Pivot/PointLight2D") as PointLight2D
	else:
		_cached_flashlight = player.get_node_or_null("PointLight2D") as PointLight2D

	return _cached_flashlight

func _is_flashlight_hitting() -> bool:
	return _is_player_flashlight_hitting() or _is_external_reactive_light_hitting()

func _is_player_flashlight_hitting() -> bool:
	var flashlight := _get_flashlight()
	if flashlight == null:
		return false
	if flashlight_requires_enabled and not flashlight.enabled:
		return false

	var origin := ReactiveLightUtils.resolve_light_origin(flashlight)
	var facing := ReactiveLightUtils.facing_from_light(flashlight)
	var light_range := flashlight_range
	if light_range <= 0.0:
		light_range = ReactiveLightUtils.resolve_point_light_range(flashlight)
	return ReactiveLightUtils.is_point_within_cone(origin, facing, global_position, light_range, flashlight_fov_deg)

func _is_flashlight_cone_hitting() -> bool:
	return _is_player_flashlight_hitting()

func _is_external_reactive_light_hitting() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for light_source in tree.get_nodes_in_group("reactive_light_source"):
		if light_source == null or not is_instance_valid(light_source):
			continue
		if light_source.is_in_group("player"):
			continue
		if not light_source.has_method("is_point_lit"):
			continue
		if bool(light_source.call("is_point_lit", global_position)):
			return true
	return false

func _is_lamp_light_hitting() -> bool:
	return _is_external_reactive_light_hitting()
