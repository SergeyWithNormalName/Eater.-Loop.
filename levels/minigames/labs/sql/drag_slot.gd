extends PanelContainer

signal word_dropped

var current_text: String = ""
var expected_text: String = "" # Правильный ответ для этой ячейки (опционально для проверки)
@onready var label = $Label # Добавь Label внутрь PanelContainer в редакторе

func can_accept_word(word_text: String) -> bool:
	if word_text == "" or current_text != "":
		return false
	if expected_text != "" and word_text != expected_text:
		return false
	return true

func set_word(word_text: String) -> void:
	current_text = word_text
	label.text = current_text
	word_dropped.emit()

func clear_word() -> void:
	if current_text == "":
		return
	current_text = ""
	label.text = ""
	word_dropped.emit()
