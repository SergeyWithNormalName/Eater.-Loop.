extends CharacterBody2D

@export var speed: float = 140.0           # Скорость движения
@export var chase_player: bool = true     # Будет ли преследовать
@export var time_penalty: float = 5.0     # Сколько секунд отнимает при касании
@export var kill_on_attack: bool = false  # Убивает игрока сразу

var _player: Node2D = null
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
var _sprite_base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	if _sprite:
		_sprite_base_scale = _sprite.scale

func _physics_process(_delta: float) -> void:
	if chase_player and _player != null:
		var delta = _player.global_position - global_position
		if abs(delta.x) < 1.0:
			velocity = Vector2.ZERO
		else:
			velocity = Vector2(sign(delta.x) * speed, 0.0)
		move_and_slide()
		_update_facing_from_velocity()
	else:
		velocity = Vector2.ZERO

func _update_facing_from_velocity() -> void:
	if _sprite == null:
		return
	if abs(velocity.x) < 0.1:
		return
	var dir = sign(velocity.x)
	_sprite.scale = Vector2(_sprite_base_scale.x * -dir, _sprite_base_scale.y)

# --- Сигналы обнаружения (Detection Area) ---

func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player = body

func _on_detection_area_body_exited(body: Node) -> void:
	if body == _player:
		_player = null

# --- Сигналы касания (Hitbox Area) ---

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_attack_player()

func _on_hitbox_area_body_exited(_body: Node2D) -> void:
	pass

func _attack_player() -> void:
	# ИСПРАВЛЕНО: phase вместо current_phase
	if kill_on_attack or GameState.phase == GameState.Phase.DISTORTED:
		UIMessage.show_text("Тебя поглотили.")
		get_tree().reload_current_scene()
		return
	# ИСПРАВЛЕНО: Теперь функция будет существовать в GameDirector
	GameDirector.reduce_time(time_penalty)
	UIMessage.show_text("Время потеряно! -%.1f с" % time_penalty)
	
	# Удаляем врага, чтобы он не кусал каждый кадр
	queue_free()
