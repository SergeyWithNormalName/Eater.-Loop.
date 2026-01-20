extends "res://scripts/objects/interactive_object.gd"

## ID ключа для проверки (должен совпадать с требованием двери).
@export var key_id: String = "bedroom_key"
## Название ключа для отображения игроку.
@export var key_name: String = "Ключ"
## Сообщение при подборе ключа.
@export_multiline var pickup_message: String = "Подобрал"

func _ready() -> void:
	super._ready()
	input_pickable = false

func _on_interact() -> void:
	_pickup()

func _pickup() -> void:
	var player = get_interacting_player()
	if player != null and player.has_method("add_key"):
		player.add_key(key_id)

	UIMessage.show_text("%s: %s" % [pickup_message, key_name])
	_hide_prompt()
	queue_free()
