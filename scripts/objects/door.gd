extends Area2D

@export var is_locked: bool = false
@export_multiline var locked_message: String = "Дверь закрыта."
@export var required_key_id: String = ""         
@export var required_key_name: String = ""       
@export var consume_key_on_unlock: bool = false

@export var target_marker: NodePath
@export var target_scene: PackedScene
@export var use_scene_change: bool = false

var _player_in_range: Node = null
var _is_transitioning: bool = false 

func _ready() -> void:
	input_pickable = false 

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body

func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null

func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning: return
	
	if event.is_action_pressed("interact") and _player_in_range != null:
		_try_use_door()

func _try_use_door() -> void:
	if is_locked:
		if required_key_id != "":
			var player_has_key: bool = _player_in_range.has_method("has_key") and _player_in_range.has_key(required_key_id)
			
			if player_has_key:
				is_locked = false
				if consume_key_on_unlock and _player_in_range.has_method("remove_key"):
					_player_in_range.remove_key(required_key_id)
				
				UIMessage.show_text("Дверь открылась.")
				_perform_transition()
				return
			else:
				if required_key_name != "":
					UIMessage.show_text("%s\nНужен: %s." % [locked_message, required_key_name])
				else:
					UIMessage.show_text(locked_message)
				return

		UIMessage.show_text(locked_message)
		return

	_perform_transition()

func _perform_transition() -> void:
	_is_transitioning = true 
	
	# === ИСПРАВЛЕНИЕ 2: Защита от вылета и побега ===
	# 1. Сохраняем ссылку на игрока локально, даже если он выйдет из зоны триггера
	var player = _player_in_range
	
	# 2. Если игрока нет или ссылка битая — выходим
	if not is_instance_valid(player):
		_is_transitioning = false
		return

	# 3. Отключаем управление игроку (замораживаем физику), чтобы он не ушел
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
		# Если есть анимации ходьбы, можно принудительно поставить Idle, 
		# но обычно отключения физики достаточно, чтобы он застыл.
	# ================================================
	
	if use_scene_change:
		if target_scene == null:
			push_warning("Door: target_scene не задан.")
			# Не забываем разморозить, если ошибка
			if is_instance_valid(player): player.set_physics_process(true)
			_is_transitioning = false
			return
		
		await UIMessage.change_scene_with_fade(target_scene)
		
	else:
		if target_marker.is_empty():
			push_warning("Door: target_marker не задан.")
			if is_instance_valid(player): player.set_physics_process(true)
			_is_transitioning = false
			return
			
		var marker := get_node_or_null(target_marker)
		if marker == null:
			push_warning("Door: target_marker не найден.")
			if is_instance_valid(player): player.set_physics_process(true)
			_is_transitioning = false
			return
		
		await UIMessage.fade_out(0.4)
		
		# Проверяем, жив ли игрок после паузы
		if is_instance_valid(player):
			player.global_position = marker.global_position
		
		await get_tree().create_timer(0.1).timeout
		await UIMessage.fade_in(0.4)
		
		# 4. Возвращаем управление
		if is_instance_valid(player) and player.has_method("set_physics_process"):
			player.set_physics_process(true)
		
		_is_transitioning = false
		
