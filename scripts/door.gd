extends Area2D

@export var is_locked: bool = false
@export_multiline var locked_message: String = "Дверь закрыта."

@export var required_key_id: String = ""         # какой ключ нужен
@export var required_key_name: String = ""       # как назвать ключ в сообщении
@export var consume_key_on_unlock: bool = false

@export var target_marker: NodePath
@export var target_scene: PackedScene
@export var use_scene_change: bool = false

var _player_in_range: Node = null

func _ready() -> void:
	input_pickable = true

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body

func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_use_door()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_in_range != null:
		_try_use_door()

func _try_use_door() -> void:
	if _player_in_range == null:
		return

	if is_locked:
		# Если дверь требует ключ
		if required_key_id != "":
			var has: bool = _player_in_range.has_method("has_key") and bool(_player_in_range.has_key(required_key_id))
			if has:
				is_locked = false

				if consume_key_on_unlock and _player_in_range.has_method("remove_key"):
					_player_in_range.remove_key(required_key_id)

				UIMessage.show_text("Дверь открылась.")
				_open_door()
				return
			else:
				# Показать причину (твой текст) + опционально подсказать ключ
				if required_key_name != "":
					UIMessage.show_text("%s\nНужен: %s." % [locked_message, required_key_name])
				else:
					UIMessage.show_text(locked_message)
				return

		# Просто заперта без ключа
		UIMessage.show_text(locked_message)
		return

	_open_door()

func _open_door() -> void:
	if use_scene_change:
		if target_scene == null:
			push_warning("Door: target_scene не задан.")
			return
		get_tree().change_scene_to_packed(target_scene)
	else:
		if target_marker.is_empty():
			push_warning("Door: target_marker не задан.")
			return
		var marker := get_node_or_null(target_marker)
		if marker == null:
			push_warning("Door: target_marker не найден.")
			return
		_player_in_range.global_position = marker.global_position
		
		
		
		
		
