extends PanelContainer

signal word_dropped

var current_text: String = ""
var expected_text: String = "" # Правильный ответ для этой ячейки (опционально для проверки)
@onready var label = $Label # Добавь Label внутрь PanelContainer в редакторе

func can_accept_word(word_text: String) -> bool:
	return current_text == "" and word_text != ""

func set_word(word_text: String) -> void:
	current_text = word_text
	label.text = current_text
	word_dropped.emit()
	
