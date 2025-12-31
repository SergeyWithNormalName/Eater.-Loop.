extends CharacterBody2D

@export var speed: float = 27.0

# Храним ключи как набор строковых ID
var keys: Dictionary = {}  # key_id -> true

func _ready() -> void:
	# На всякий случай — чтобы двери/ключи находили игрока по группе
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
	print("Игрок: получил ключ '", key_id, "'")

func has_key(key_id: String) -> bool:
	if key_id == "":
		return false
	return keys.has(key_id)

func remove_key(key_id: String) -> void:
	if keys.has(key_id):
		keys.erase(key_id)
		print("Игрок: ключ '", key_id, "' использован/потрачен")
