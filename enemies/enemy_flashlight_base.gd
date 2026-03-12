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
	var player := _player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.has_method("is_point_lit") and flashlight_requires_enabled:
		for probe_point in _get_flashlight_hit_points():
			if bool(player.call("is_point_lit", probe_point)):
				return true
		return false

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
	for probe_point in _get_flashlight_hit_points():
		if ReactiveLightUtils.is_point_within_cone(origin, facing, probe_point, light_range, flashlight_fov_deg):
			return true
	return false

func _is_flashlight_cone_hitting() -> bool:
	return _is_player_flashlight_hitting()

func _is_external_reactive_light_hitting() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var probe_points := _get_flashlight_hit_points()
	for light_source in tree.get_nodes_in_group("reactive_light_source"):
		if light_source == null or not is_instance_valid(light_source):
			continue
		if light_source.is_in_group("player"):
			continue
		if not light_source.has_method("is_point_lit"):
			continue
		for probe_point in probe_points:
			if bool(light_source.call("is_point_lit", probe_point)):
				return true
	return false

func _is_lamp_light_hitting() -> bool:
	return _is_external_reactive_light_hitting()

func _get_flashlight_hit_points() -> Array[Vector2]:
	var points: Array[Vector2] = [global_position]
	var body_shape := _find_body_collision_shape()
	if body_shape != null:
		_append_collision_shape_probe_points(points, body_shape)
		return points
	_append_sprite_probe_points(points)
	return points

func _find_body_collision_shape() -> CollisionShape2D:
	for child in get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape != null and collision_shape.shape != null:
			return collision_shape
	return null

func _append_collision_shape_probe_points(points: Array[Vector2], collision_shape: CollisionShape2D) -> void:
	var shape := collision_shape.shape
	if shape is RectangleShape2D:
		var half_size := (shape as RectangleShape2D).size * 0.5
		var local_points := [
			Vector2(0.0, -half_size.y * 0.75),
			Vector2(0.0, -half_size.y * 0.35),
			Vector2(0.0, half_size.y * 0.35),
			Vector2(-half_size.x * 0.5, 0.0),
			Vector2(half_size.x * 0.5, 0.0),
		]
		for local_point in local_points:
			points.append(collision_shape.to_global(local_point))
		return
	if shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		var local_points := [
			Vector2(0.0, -radius * 0.75),
			Vector2(0.0, radius * 0.75),
			Vector2(-radius * 0.75, 0.0),
			Vector2(radius * 0.75, 0.0),
		]
		for local_point in local_points:
			points.append(collision_shape.to_global(local_point))

func _append_sprite_probe_points(points: Array[Vector2]) -> void:
	var canvas_sprite := _sprite as CanvasItem
	if canvas_sprite == null or not canvas_sprite.has_method("get_rect"):
		return
	var rect: Variant = canvas_sprite.call("get_rect")
	if not (rect is Rect2):
		return
	var bounds := rect as Rect2
	if bounds.size == Vector2.ZERO:
		return
	var local_points := [
		bounds.get_center(),
		Vector2(bounds.get_center().x, bounds.position.y + bounds.size.y * 0.2),
		Vector2(bounds.get_center().x, bounds.position.y + bounds.size.y * 0.8),
		Vector2(bounds.position.x + bounds.size.x * 0.2, bounds.get_center().y),
		Vector2(bounds.position.x + bounds.size.x * 0.8, bounds.get_center().y),
	]
	for local_point in local_points:
		points.append((canvas_sprite as Node2D).to_global(local_point))
