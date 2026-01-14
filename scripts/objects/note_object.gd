extends Area2D

## Текстура записки для просмотра.
@export var note_texture: Texture2D # Сюда перетаскиваешь картинку в Инспекторе
## Подсказка при наведении (опционально).
@export_multiline var interact_message: String = "Прочитать" # Подсказка при наведении (опционально)

var _player_in_range: bool = false

func _ready() -> void:
	# На всякий случай проверяем сигналы, но лучше подключить их через узел
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if InteractionPrompts:
			var prompt_text := interact_message.strip_edges()
			if prompt_text != "":
				InteractionPrompts.show_interact(self, "E — %s" % prompt_text)
			else:
				InteractionPrompts.show_interact(self)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if InteractionPrompts:
			InteractionPrompts.hide_interact(self)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
		
	if event.is_action_pressed("interact"):
		if note_texture:
			UIMessage.show_note(note_texture)
		else:
			UIMessage.show_text("Тут ничего не написано.") # Заглушка, если забыл картинку
