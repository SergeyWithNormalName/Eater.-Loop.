extends "res://objects/interactable/powered_switchable_interactable.gd"

@export_group("Projector Settings")
@export_range(1.0, 180.0, 1.0) var light_fov_deg: float = 78.0
@export var beam_direction_local: Vector2 = Vector2(1.0, -0.18)

@export_group("Beam Visual")
@export var beam_visual_node: NodePath = NodePath("BeamVisual")
@export var beam_core_node: NodePath = NodePath("BeamCore")
@export var beam_origin_local: Vector2 = Vector2(60.0, -20.0)
@export var sync_light_origin_with_beam: bool = true
@export_range(64.0, 2400.0, 1.0) var beam_visual_length: float = 980.0
@export_range(8.0, 800.0, 1.0) var beam_visual_near_width: float = 92.0
@export_range(16.0, 1600.0, 1.0) var beam_visual_far_width: float = 920.0
@export var beam_visual_color: Color = Color(1.0, 0.96, 0.88, 1.0)
@export_range(0.0, 1.0, 0.01) var beam_visual_alpha: float = 0.42
@export_range(0.0, 1.0, 0.01) var beam_visual_core_alpha: float = 0.24
@export_range(0.0, 1.0, 0.01) var beam_visual_start_softness: float = 0.04
@export_range(0.01, 1.0, 0.01) var beam_visual_end_softness: float = 0.4
@export_range(0.01, 0.5, 0.01) var beam_visual_edge_softness: float = 0.18
@export_range(0.1, 4.0, 0.01) var beam_visual_spread_curve: float = 0.92
@export_range(0.1, 4.0, 0.01) var beam_visual_length_falloff: float = 1.15
@export_range(0.5, 8.0, 0.01) var beam_visual_core_power: float = 2.8
@export_range(0.0, 1.0, 0.01) var beam_visual_origin_strength: float = 1.0
@export_range(0.05, 1.0, 0.01) var beam_core_width_ratio: float = 0.42

var _beam_visual: Polygon2D = null
var _beam_core: Polygon2D = null

func _ready() -> void:
	super._ready()
	_beam_visual = get_node_or_null(beam_visual_node) as Polygon2D
	_beam_core = get_node_or_null(beam_core_node) as Polygon2D
	process_mode = Node.PROCESS_MODE_INHERIT
	_configure_beam_visual()
	_refresh_beam_visual()

func _process(_delta: float) -> void:
	_refresh_beam_visual()

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

func _update_output_state(play_sound: bool) -> void:
	super._update_output_state(play_sound)
	_refresh_beam_visual()

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

func _configure_beam_visual() -> void:
	if _beam_visual == null and _beam_core == null:
		return
	var local_direction := beam_direction_local
	if local_direction.length_squared() <= 0.000001:
		local_direction = Vector2.RIGHT
	var normalized_direction := local_direction.normalized()
	var side := Vector2(-normalized_direction.y, normalized_direction.x)
	var start_half_width := beam_visual_near_width * 0.5
	var end_half_width := beam_visual_far_width * 0.5
	var start_center := beam_origin_local
	var end_center := beam_origin_local + normalized_direction * beam_visual_length
	if sync_light_origin_with_beam and _light != null:
		_light.position = beam_origin_local
	_configure_beam_polygon(
		_beam_visual,
		start_center,
		end_center,
		side,
		start_half_width,
		end_half_width,
		beam_visual_alpha,
		beam_visual_color
	)
	_configure_beam_polygon(
		_beam_core,
		start_center,
		end_center,
		side,
		start_half_width * beam_core_width_ratio,
		end_half_width * beam_core_width_ratio,
		beam_visual_core_alpha,
		beam_visual_color.lightened(0.08)
	)

func _configure_beam_polygon(
	polygon_node: Polygon2D,
	start_center: Vector2,
	end_center: Vector2,
	side: Vector2,
	start_half_width: float,
	end_half_width: float,
	alpha: float,
	color: Color
) -> void:
	if polygon_node == null:
		return
	polygon_node.polygon = PackedVector2Array([
		start_center - side * start_half_width,
		start_center + side * start_half_width,
		end_center + side * end_half_width,
		end_center - side * end_half_width,
	])
	polygon_node.color = Color.WHITE
	polygon_node.vertex_colors = PackedColorArray([
		Color(color.r, color.g, color.b, alpha),
		Color(color.r, color.g, color.b, alpha),
		Color(color.r, color.g, color.b, 0.0),
		Color(color.r, color.g, color.b, 0.0),
	])

func _refresh_beam_visual() -> void:
	var should_be_visible := is_light_active()
	if _beam_visual != null and _beam_visual.visible != should_be_visible:
		_beam_visual.visible = should_be_visible
	if _beam_core != null and _beam_core.visible != should_be_visible:
		_beam_core.visible = should_be_visible
