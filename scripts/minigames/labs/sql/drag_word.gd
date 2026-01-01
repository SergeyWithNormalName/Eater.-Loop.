extends Button

var text_value: String = ""

func _ready():
	text = text_value
	custom_minimum_size = Vector2(80, 40) # Примерный размер

func _get_drag_data(at_position):
	# Создаем визуальную копию того, что тащим
	var preview = Button.new()
	preview.text = text
	preview.size = size
	set_drag_preview(preview)
	
	# Возвращаем данные: текст и ссылку на сам объект (чтобы можно было скрыть/удалить при желании)
	return { "text": text_value, "source": self }
	
