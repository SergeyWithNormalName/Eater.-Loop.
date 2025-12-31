extends CharacterBody2D

@export var speed: float = 520 # Подкорректируй скорость, 27.0 кажется очень малой для пикселей

# Храним ключи как набор строковых ID: key_id -> true
var keys: Dictionary = {}

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed
	velocity.y = 0
	move_and_slide()

# ===== Работа с ключами =====

func add_key(key_id: String) -> void:
	if key_id == "":
		return
	keys[key_id] = true

func has_key(key_id: String) -> bool:
	if key_id == "":
		return false
	return keys.has(key_id)

func remove_key(key_id: String) -> void:
	if keys.has(key_id):
		keys.erase(key_id)
