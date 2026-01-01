extends CharacterBody2D

@export var speed: float = 520.0

var keys: Dictionary = {}

# Ссылки на узлы
@onready var pivot: Node2D = get_node_or_null("Pivot") as Node2D
@onready var sprite: Node2D = get_node_or_null("Sprite2D") as Node2D
@onready var flashlight: PointLight2D = null

var _facing_dir: float = 1.0
var _pivot_base_scale: Vector2 = Vector2.ONE
var _sprite_base_scale: Vector2 = Vector2.ONE
var _flashlight_base_scale: Vector2 = Vector2.ONE
var _flashlight_base_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")
	
	if pivot and pivot.has_node("PointLight2D"):
		flashlight = pivot.get_node("PointLight2D") as PointLight2D
	else:
		flashlight = get_node_or_null("PointLight2D") as PointLight2D
	
	if pivot:
		_pivot_base_scale = pivot.scale
	if sprite:
		_sprite_base_scale = sprite.scale
	if flashlight:
		_flashlight_base_scale = flashlight.scale
		_flashlight_base_offset = flashlight.offset
	
	_apply_facing()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if abs(direction) < 0.1:
		direction = 0.0
	
	velocity.x = direction * speed
	velocity.y = 0
	move_and_slide()

	# ===== ЛОГИКА ПОВОРОТА (ЗЕРКАЛИМ ТОЛЬКО ВИЗУАЛ) =====
	if direction != 0:
		_facing_dir = sign(direction)
		_apply_facing()

func _apply_facing() -> void:
	# Зеркалим только визуальную часть, коллизии и камера не дергаются.
	if pivot:
		pivot.scale = Vector2(abs(_pivot_base_scale.x) * _facing_dir, _pivot_base_scale.y)
		return
	
	if sprite:
		sprite.scale = Vector2(abs(_sprite_base_scale.x) * _facing_dir, _sprite_base_scale.y)
	if flashlight:
		flashlight.scale = Vector2(abs(_flashlight_base_scale.x) * _facing_dir, _flashlight_base_scale.y)
		# Offset уже "зеркалится" вместе со scale, дополнительный флип ломает позицию.
		flashlight.offset = _flashlight_base_offset

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_flashlight"):
		if flashlight:
			flashlight.enabled = !flashlight.enabled

# ===== Работа с ключами (без изменений) =====
func add_key(key_id: String) -> void:
	if key_id == "": return
	keys[key_id] = true

func has_key(key_id: String) -> bool:
	if key_id == "": return false
	return keys.has(key_id)

func remove_key(key_id: String) -> void:
	if keys.has(key_id): keys.erase(key_id)
