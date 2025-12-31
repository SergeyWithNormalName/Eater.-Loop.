extends CharacterBody2D

@export var speed: float = 140.0           # Скорость движения
@export var chase_player: bool = true     # Будет ли преследовать
@export var time_penalty: float = 5.0     # Сколько секунд отнимает при касании

var _player: Node2D = null

func _physics_process(_delta: float) -> void:
	if chase_player and _player != null:
		# Двигаемся к игроку
		var direction = global_position.direction_to(_player.global_position)
		velocity = direction * speed
		move_and_slide()
	else:
		# Если не преследуем или не видим игрока, стоим (или можно добавить патруль)
		velocity = Vector2.ZERO

# --- Сигналы обнаружения (Detection Area) ---

func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player = body

func _on_detection_area_body_exited(body: Node) -> void:
	if body == _player:
		_player = null

# --- Сигналы касания (Hitbox Area) ---

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_attack_player()

func _attack_player() -> void:
	if GameState.current_phase == GameState.Phase.DISTORTED:
		# Фаза искажения: смерть / перезагрузка уровня
		UIMessage.show_text("Тебя поглотили.")
		get_tree().reload_current_scene()
	else:
		# Нормальная фаза: отнимаем время
		GameDirector.reduce_time(time_penalty)
		UIMessage.show_text("Время потеряно! -%.1f с" % time_penalty)
		
		# Важно: удаляем врага после касания в нормальной фазе,
		# иначе он будет отнимать время каждый кадр и мгновенно убьёт таймер.
		queue_free()


func _on_hitbox_area_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
