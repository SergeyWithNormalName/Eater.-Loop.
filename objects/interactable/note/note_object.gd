extends "res://objects/interactable/interactive_object.gd"

## Текстура записки для просмотра.
@export var note_texture: Texture2D # Сюда перетаскиваешь картинку в Инспекторе
## Подсказка при наведении (опционально).
@export_multiline var interact_message: String = "Прочитать" # Подсказка при наведении (опционально)

func _ready() -> void:
	super._ready()

func _get_prompt_text() -> String:
	var message_text := interact_message.strip_edges()
	if message_text == "":
		return ""
	return "E — %s" % message_text

func _on_interact() -> void:
	if note_texture:
		UIMessage.show_note(note_texture)
	else:
		UIMessage.show_text("Тут ничего не написано.") # Заглушка, если забыл картинку
