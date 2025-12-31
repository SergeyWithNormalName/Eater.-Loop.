extends CharacterBody2D

@export var speed: float = 140.0           # Скорость движения
@export var chase_player: bool = true     # Будет ли преследовать
@export var time_penalty: float = 5.0     # Сколько секунд отнимает при касании

var _player: Node2D = null

func _physics_process(_delta: float) -> void:
	if chase_player and _player != null:
		var direction = global_position.direction_to(_player.global_position)
		velocity = direction * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

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

func _attack_player() -> void:
	# ИСПРАВЛЕНО: phase вместо current_phase
	if GameState.phase == GameState.Phase.DISTORTED:
		UIMessage.show_text("Тебя поглотили.")
		get_tree().reload_current_scene()
	else:
		# ИСПРАВЛЕНО: Теперь функция будет существовать в GameDirector
		GameDirector.reduce_time(time_penalty)
		UIMessage.show_text("Время потеряно! -%.1f с" % time_penalty)
		
		# Удаляем врага, чтобы он не кусал каждый кадр
		queue_free()
