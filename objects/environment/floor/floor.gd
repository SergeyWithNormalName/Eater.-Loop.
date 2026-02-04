@tool
extends Node2D

const FLOOR_SHADER: Shader = preload("res://objects/environment/floor/floor_perspective.gdshader")

# --- Текстура и размер ---
## Текстура пола (обычная, без перспективы)
@export var floor_texture: Texture2D : set = _set_floor_texture
## Размер плоскости пола в пикселях сцены; если (0,0), масштаб задается вручную
@export var size: Vector2 = Vector2(2048, 512) : set = _set_size

# --- Текстура (тайлинг) ---
## Сколько раз повторить текстуру по X/Y
@export var tiling: Vector2 = Vector2(5, 3) : set = _set_tiling
## Смещение тайлинга по X/Y (в долях тайла)
@export var offset: Vector2 = Vector2.ZERO : set = _set_offset

# --- Перспектива ---
@export_group("Perspective")
## Общая сила перспективы по глубине (0 = плоско)
@export var perspective_amount: float = 0.6 : set = _set_perspective_amount
## Центр схода по X (0..1, 0.5 = центр)
@export var vanish_x: float = 0.5 : set = _set_vanish_x
## Уровень горизонта по Y (0 = верх спрайта, 1 = низ)
@export var horizon: float = 0.0 : set = _set_horizon
## Дополнительное растяжение по X для формы "трапеции"
@export var x_scale: float = 1.0 : set = _set_x_scale
## Сила искажения по краям (0 = без искажения)
@export var edge_strength: float = 1.0 : set = _set_edge_strength
## Насколько резко включается искажение у краёв (больше = резче)
@export var edge_power: float = 2.0 : set = _set_edge_power
## Ширина "почти плоского" центра (в долях ширины, 0..0.49)
@export var center_width: float = 0.15 : set = _set_center_width
## Где искажение достигает максимума (в долях ширины, 0.01..0.5)
@export var edge_end: float = 0.5 : set = _set_edge_end
## Максимальная глубина отрисовки (в условных единицах глубины)
@export var max_distance: float = 10.0 : set = _set_max_distance
## Плавное затухание у горизонта (0 = без затухания)
@export var fade_length: float = 1.0 : set = _set_fade_length
## Смещение уровня мипов (отрицательное = резче, положительное = мягче)
@export var mip_bias: float = 0.0 : set = _set_mip_bias

func _ready() -> void:
	_sync_all()

func _set_floor_texture(value: Texture2D) -> void:
	floor_texture = value
	_sync_all()

func _set_size(value: Vector2) -> void:
	size = value
	_sync_size()

func _set_tiling(value: Vector2) -> void:
	tiling = value
	_sync_material()

func _set_offset(value: Vector2) -> void:
	offset = value
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

func _set_fade_length(value: float) -> void:
	fade_length = value
	_sync_material()

func _set_mip_bias(value: float) -> void:
	mip_bias = value
	_sync_material()

func _sync_all() -> void:
	_ensure_material()
	_sync_texture()
	_sync_size()
	_sync_material()

func _ensure_material() -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return
	var mat := sprite.material
	if mat == null or not (mat is ShaderMaterial):
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = FLOOR_SHADER
		sprite.material = shader_mat
		return
	var shader_mat := mat as ShaderMaterial
	if shader_mat.shader != FLOOR_SHADER:
		shader_mat.shader = FLOOR_SHADER

func _sync_texture() -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return
	if floor_texture != null:
		sprite.texture = floor_texture

func _sync_size() -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if floor_texture == null:
		return
	var tex_size := floor_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	sprite.scale = size / tex_size

func _sync_material() -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("tiling", tiling)
	mat.set_shader_parameter("offset", offset)
	mat.set_shader_parameter("perspective_amount", perspective_amount)
	mat.set_shader_parameter("vanish_x", vanish_x)
	mat.set_shader_parameter("horizon", horizon)
	mat.set_shader_parameter("x_scale", x_scale)
	mat.set_shader_parameter("edge_strength", edge_strength)
	mat.set_shader_parameter("edge_power", edge_power)
	mat.set_shader_parameter("center_width", center_width)
	mat.set_shader_parameter("edge_end", edge_end)
	mat.set_shader_parameter("max_distance", max_distance)
	mat.set_shader_parameter("fade_length", fade_length)
	mat.set_shader_parameter("mip_bias", mip_bias)

func _get_sprite() -> Sprite2D:
	return get_node_or_null("Sprite2D") as Sprite2D
