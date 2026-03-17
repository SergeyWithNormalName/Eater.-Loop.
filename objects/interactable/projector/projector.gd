extends "res://objects/interactable/powered_switchable_interactable.gd"

@export_group("Projector Settings")
@export_range(1.0, 180.0, 1.0) var light_fov_deg: float = 36.0
@export var beam_direction_local: Vector2 = Vector2.RIGHT

func is_point_lit(point: Vector2) -> bool:
	if not is_light_active():
		return false
	var origin := ReactiveLightUtils.resolve_light_origin(_light)
	var facing := _resolve_beam_direction()
	return ReactiveLightUtils.is_point_within_cone(origin, facing, point, light_range, light_fov_deg)

func _get_switch_prompt_text() -> String:
	if is_light_active():
		return tr("Q — выключить проектор")
	return tr("Q — включить проектор")

func _update_sprite(is_lit: bool) -> void:
	if _sprite == null:
		return
	if is_lit and on_texture != null:
		_sprite.texture = on_texture
	elif not is_lit and off_texture != null:
		_sprite.texture = off_texture
	elif on_texture == null and off_texture == null:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_lit else Color(0.72, 0.72, 0.72, 1.0)

func _resolve_beam_direction() -> Vector2:
	var local_direction := beam_direction_local
	if local_direction.length_squared() <= 0.000001:
		local_direction = Vector2.RIGHT
	var facing := global_transform.basis_xform(local_direction.normalized())
	if facing.length_squared() <= 0.000001:
		return Vector2.RIGHT
	return facing.normalized()
