extends RefCounted
class_name ReactiveLightUtils

static func resolve_light_origin(light: PointLight2D) -> Vector2:
	if light == null:
		return Vector2.ZERO
	return light.global_transform * light.offset

static func resolve_point_light_range(light: PointLight2D, fallback_range: float = -1.0) -> float:
	if fallback_range > 0.0:
		return fallback_range
	if light == null or light.texture == null:
		return 0.0
	var base_radius: float = maxf(float(light.texture.get_width()), float(light.texture.get_height())) * 0.5
	if base_radius <= 0.0:
		return 0.0
	var scale_factor: float = maxf(absf(light.global_scale.x), absf(light.global_scale.y))
	return base_radius * max(0.001, light.texture_scale) * max(0.001, scale_factor)

static func facing_from_light(light: PointLight2D) -> Vector2:
	if light == null:
		return Vector2.LEFT
	var facing := -light.global_transform.x
	if facing.length_squared() <= 0.000001:
		return Vector2.LEFT
	return facing.normalized()

static func is_point_within_radius(origin: Vector2, point: Vector2, light_range: float) -> bool:
	if light_range <= 0.0:
		return false
	return origin.distance_to(point) <= light_range

static func is_point_within_cone(
	origin: Vector2,
	facing: Vector2,
	point: Vector2,
	light_range: float,
	fov_deg: float
) -> bool:
	var to_point := point - origin
	var distance := to_point.length()
	if light_range > 0.0 and distance > light_range:
		return false
	if distance <= 0.001:
		return true
	if fov_deg <= 0.0:
		return true
	var normalized_facing := facing.normalized()
	var half_angle := deg_to_rad(fov_deg) * 0.5
	return normalized_facing.dot(to_point.normalized()) >= cos(half_angle)
