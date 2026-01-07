extends "res://scripts/enemy.gd"

@export_group("Flashlight Detection")
@export var flashlight_range: float = 650.0
@export var flashlight_fov_deg: float = 90.0
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
