@tool
extends Node2D

# --- Текстура и размер ---
@export var floor_texture: Texture2D : set = _set_floor_texture
# Если size = (0,0), масштаб задается вручную
@export var size: Vector2 = Vector2(2048, 512) : set = _set_size

# --- Текстура (тайлинг) ---
@export var tiling: Vector2 = Vector2(5, 3) : set = _set_tiling
@export var offset: Vector2 = Vector2.ZERO : set = _set_offset

# --- Перспектива ---
@export_group("Perspective")
@export var perspective_amount: float = 0.8 : set = _set_perspective_amount
@export var flat_start: float = 0.55 : set = _set_flat_start
@export var flat_end: float = 1.0 : set = _set_flat_end
@export var curve: float = 3.0 : set = _set_curve
@export var vanish_x: float = 0.5 : set = _set_vanish_x
@export var horizon: float = 0.0 : set = _set_horizon
@export var x_scale: float = 1.0 : set = _set_x_scale
@export var fade_height: float = 0.03 : set = _set_fade_height

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

func _set_flat_start(value: float) -> void:
    flat_start = value
    _sync_material()

func _set_flat_end(value: float) -> void:
    flat_end = value
    _sync_material()

func _set_curve(value: float) -> void:
    curve = value
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

func _set_fade_height(value: float) -> void:
    fade_height = value
    _sync_material()

func _sync_all() -> void:
    _sync_texture()
    _sync_size()
    _sync_material()

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
    mat.set_shader_parameter("flat_start", flat_start)
    mat.set_shader_parameter("flat_end", flat_end)
    mat.set_shader_parameter("curve", curve)
    mat.set_shader_parameter("vanish_x", vanish_x)
    mat.set_shader_parameter("horizon", horizon)
    mat.set_shader_parameter("x_scale", x_scale)
    mat.set_shader_parameter("fade_height", fade_height)

func _get_sprite() -> Sprite2D:
    return get_node_or_null("Sprite2D") as Sprite2D
