@tool
extends Sprite2D

const TABLE_SHADER: Shader = preload("res://objects/environment/floor/table_perspective.gdshader")

@export_group("Sync")
@export var sync_from_floor: bool = true : set = _set_sync_from_floor
@export var floor_path: NodePath : set = _set_floor_path
@export var floor_perspective_scale: float = 0.28 : set = _set_floor_perspective_scale

@export_group("Perspective")
@export var perspective_amount: float = 0.55 : set = _set_perspective_amount
@export var vanish_x: float = 0.5 : set = _set_vanish_x
@export var horizon: float = -3.73 : set = _set_horizon
@export var x_scale: float = 1.0 : set = _set_x_scale
@export var edge_strength: float = 1.0 : set = _set_edge_strength
@export var edge_power: float = 2.0 : set = _set_edge_power
@export var center_width: float = 0.0 : set = _set_center_width
@export var edge_end: float = 0.5 : set = _set_edge_end
@export var max_distance: float = 10.0 : set = _set_max_distance
@export var vertical_power: float = 1.35 : set = _set_vertical_power

func _ready() -> void:
	_ensure_material()
	_sync_material()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_material()

func _set_sync_from_floor(value: bool) -> void:
	sync_from_floor = value
	_sync_material()

func _set_floor_path(value: NodePath) -> void:
	floor_path = value
	_sync_material()

func _set_floor_perspective_scale(value: float) -> void:
	floor_perspective_scale = value
	_sync_material()

func _set_perspective_amount(value: float) -> void:
	perspective_amount = value
	_sync_material()

func _set_vanish_x(value: float) -> void:
	vanish_x = value
	_sync_material()

func _set_horizon(value: float) -> void:
	horizon = value
	_sync_material()

func _set_x_scale(value: float) -> void:
	x_scale = value
	_sync_material()

func _set_edge_strength(value: float) -> void:
	edge_strength = value
	_sync_material()

func _set_edge_power(value: float) -> void:
	edge_power = value
	_sync_material()

func _set_center_width(value: float) -> void:
	center_width = value
	_sync_material()

func _set_edge_end(value: float) -> void:
	edge_end = value
	_sync_material()

func _set_max_distance(value: float) -> void:
	max_distance = value
	_sync_material()

func _set_vertical_power(value: float) -> void:
	vertical_power = value
	_sync_material()

func _ensure_material() -> void:
	var mat := material
	var shader_mat: ShaderMaterial = null
	if mat == null or not (mat is ShaderMaterial):
		shader_mat = ShaderMaterial.new()
	else:
		shader_mat = mat as ShaderMaterial
		if not shader_mat.resource_local_to_scene:
			shader_mat = shader_mat.duplicate() as ShaderMaterial
	if shader_mat == null:
		return
	if not shader_mat.resource_local_to_scene:
		shader_mat.resource_local_to_scene = true
	if shader_mat.shader != TABLE_SHADER:
		shader_mat.shader = TABLE_SHADER
	if material != shader_mat:
		material = shader_mat

func _sync_material() -> void:
	_ensure_material()
	var mat := material as ShaderMaterial
	if mat == null:
		return

	var p := perspective_amount
	var vx := vanish_x
	var hz := horizon
	var xs := x_scale
	var es := edge_strength
	var ep := edge_power
	var cw := center_width
	var ee := edge_end
	var md := max_distance

	if sync_from_floor:
		var floor_node := get_node_or_null(floor_path)
		if floor_node != null:
			p = _read_float_property(floor_node, &"perspective_amount", p) * floor_perspective_scale
			vx = _read_float_property(floor_node, &"vanish_x", vx)
			hz = _read_float_property(floor_node, &"horizon", hz)
			xs = _read_float_property(floor_node, &"x_scale", xs)
			es = _read_float_property(floor_node, &"edge_strength", es)
			ep = _read_float_property(floor_node, &"edge_power", ep)
			cw = _read_float_property(floor_node, &"center_width", cw)
			ee = _read_float_property(floor_node, &"edge_end", ee)
			md = _read_float_property(floor_node, &"max_distance", md)

	mat.set_shader_parameter("perspective_amount", p)
	mat.set_shader_parameter("vanish_x", vx)
	mat.set_shader_parameter("horizon", hz)
	mat.set_shader_parameter("x_scale", xs)
	mat.set_shader_parameter("edge_strength", es)
	mat.set_shader_parameter("edge_power", ep)
	mat.set_shader_parameter("center_width", cw)
	mat.set_shader_parameter("edge_end", ee)
	mat.set_shader_parameter("max_distance", md)
	mat.set_shader_parameter("vertical_power", vertical_power)

func _read_float_property(target: Object, property_name: StringName, fallback: float) -> float:
	if target == null:
		return fallback
	var has_property := false
	for property_info in target.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			has_property = true
			break
	if not has_property:
		return fallback
	var value: Variant = target.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback
