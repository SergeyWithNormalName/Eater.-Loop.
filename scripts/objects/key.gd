extends Area2D

## ID ключа для проверки (должен совпадать с требованием двери).
@export var key_id: String = "bedroom_key"
## Название ключа для отображения игроку.
@export var key_name: String = "Ключ"
## Сообщение при подборе ключа.
@export_multiline var pickup_message: String = "Подобрал"

var _player_in_range: Node = null

func _ready() -> void:
	input_pickable = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body
		if InteractionPrompts:
			InteractionPrompts.show_interact(self)

func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null
		if InteractionPrompts:
			InteractionPrompts.hide_interact(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_in_range != null:
		_pickup()

func _pickup() -> void:
	if _player_in_range.has_method("add_key"):
		_player_in_range.add_key(key_id)

	UIMessage.show_text("%s: %s" % [pickup_message, key_name])
	if InteractionPrompts:
		InteractionPrompts.hide_interact(self)
	queue_free()
