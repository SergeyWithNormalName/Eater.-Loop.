extends "res://enemies/enemy.gd"

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
	return _is_flashlight_cone_hitting() or _is_lamp_light_hitting()

func _is_flashlight_cone_hitting() -> bool:
	var flashlight := _get_flashlight()
	if flashlight == null:
		return false
	if flashlight_requires_enabled and not flashlight.enabled:
		return false

	var origin := flashlight.global_transform * flashlight.offset
	var to_self := global_position - origin
	var distance := to_self.length()
	if flashlight_range > 0.0 and distance > flashlight_range:
		return false
	if distance <= 0.001:
		return true
	if flashlight_fov_deg <= 0.0:
		return true

	var facing := -flashlight.global_transform.x.normalized()
	var half_angle := deg_to_rad(flashlight_fov_deg) * 0.5
	return facing.dot(to_self.normalized()) >= cos(half_angle)

func _is_lamp_light_hitting() -> bool:
	var lights := get_tree().get_nodes_in_group("lamp_light")
	for light_node in lights:
		var light := light_node as PointLight2D
		if light == null:
			continue
		if not light.enabled:
			continue
		if not light.visible:
			continue
		if light.texture == null:
			continue

		var origin := light.global_transform * light.offset
		var base_radius = max(light.texture.get_width(), light.texture.get_height()) * 0.5
		if base_radius <= 0.0:
			continue
		var scale_factor = max(light.global_scale.x, light.global_scale.y)
		var light_range = base_radius * max(0.001, light.texture_scale) * max(0.001, scale_factor)
		if origin.distance_to(global_position) <= light_range:
			return true
	return false
