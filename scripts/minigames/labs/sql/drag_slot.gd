extends PanelContainer

signal word_dropped

var current_text: String = ""
var expected_text: String = "" # Правильный ответ для этой ячейки (опционально для проверки)
@onready var label = $Label # Добавь Label внутрь PanelContainer в редакторе

func _can_drop_data(at_position, data):
	# Разрешаем сброс, если данные содержат текст
	return data.has("text")

func _drop_data(at_position, data):
	current_text = data["text"]
	label.text = current_text
	word_dropped.emit() # Сообщаем мини-игре, что что-то положили
	
