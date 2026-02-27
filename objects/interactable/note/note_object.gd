extends "res://objects/interactable/interactive_object.gd"

## Узел Sprite2D заметки в сцене.
@export var sprite_node: NodePath = NodePath("Sprite2D")
## Текстура спрайта заметки в мире.
@export var world_texture: Texture2D
## Текстура записки для просмотра.
@export var note_texture: Texture2D # Сюда перетаскиваешь картинку в Инспекторе
## Подсказка при наведении (опционально).
@export_multiline var interact_message: String = "Прочитать" # Подсказка при наведении (опционально)
## ID ключа, который выдается при чтении (пусто — не выдавать).
@export var reward_key_id: String = ""
## Субтитр при выдаче ключа (показывается, только если reward_key_id не пустой).
@export_multiline var reward_subtitle: String = ""

var _sprite: Sprite2D = null

func _ready() -> void:
	super._ready()
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	if _sprite and world_texture:
		_sprite.texture = world_texture

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
	_give_reward_key()

func _give_reward_key() -> void:
	var key_id := reward_key_id.strip_edges()
	if key_id == "":
		return

	var player := get_interacting_player()
	if player != null and player.has_method("add_key"):
		player.add_key(key_id)

	var subtitle_text := reward_subtitle.strip_edges()
	if subtitle_text != "":
		UIMessage.show_subtitle(subtitle_text)
