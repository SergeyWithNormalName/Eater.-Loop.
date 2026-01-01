extends Control

signal task_completed(success: bool)

# Настройки для Инспектора (передадим их из объекта Ноутбука)
var time_limit: float = 60.0
var penalty_time: float = 15.0
var quest_id: String = "" # ID текущей лабы, чтобы открыть двери

# Данные заданий (можно вынести в отдельный ресурс JSON, но пока так)
# "template": структура запроса, где null - это пустая ячейка
var tasks = [
	{
		"description": "Выбрать всех студентов из таблицы Users",
		"template": ["SELECT", null, "FROM", null],
		"correct": ["*", "Users"],
		"pool": ["SELECT", "*", "FROM", "Users", "WHERE", "DROP"]
	},
	{
		"description": "Найти должников (debt > 0)",
		"template": ["SELECT", "*", "FROM", "Students", "WHERE", null, ">", null],
		"correct": ["debt", "0"],
		"pool": ["debt", "0", "id", "NULL", "100", ">", "Students"]
	},
	{
		"description": "Удалить таблицу Долги (Осторожно!)",
		"template": [null, "TABLE", null],
		"correct": ["DROP", "Debts"],
		"pool": ["DELETE", "DROP", "TABLE", "Debts", "Row", "*"]
	}
]

var current_task_index = 0
var current_time = 0.0

@onready var query_container = $QueryArea
@onready var pool_container = $WordPool
@onready var task_label = $Header/TaskLabel
@onready var timer_label = $Header/TimerLabel
@onready var progress_container = $Header/ProgressContainer

# Префабы (загрузи их или создай кодом, здесь пример кодом для простоты, 
# но лучше назначить .tscn файлы в инспекторе)
var slot_scene = preload("res://scenes/minigames/ui/drop_slot.tscn") 
var word_scene = preload("res://scenes/minigames/ui/drag_word.tscn")

func _ready():
	# Ставим игру на паузу
	get_tree().paused = true
	current_time = time_limit
	update_progress_ui()
	load_task(0)

func _process(delta):
	if current_time > 0:
		current_time -= delta
		timer_label.text = "ОСТАЛОСЬ: %.1f сек" % current_time
		if current_time <= 0:
			finish_game(false)

func load_task(index):
	current_task_index = index
	var data = tasks[index]
	
	task_label.text = data["description"]
	
	# Очистка старого
	for child in query_container.get_children(): child.queue_free()
	for child in pool_container.get_children(): child.queue_free()
	
	# Генерация слотов запроса
	for item in data["template"]:
		if item == null:
			# Это пустой слот для перетаскивания
			var slot = slot_scene.instantiate()
			query_container.add_child(slot)
			slot.word_dropped.connect(check_answer)
		else:
			# Это фиксированное слово (просто Label или заблокированная кнопка)
			var static_lbl = Label.new()
			static_lbl.text = item
			query_container.add_child(static_lbl)
			
	# Генерация слов для выбора
	for word_text in data["pool"]:
		var word = word_scene.instantiate()
		word.text_value = word_text
		pool_container.add_child(word)
		
	update_progress_ui()

func check_answer():
	var data = tasks[current_task_index]
	var slots = []
	
	# Собираем все слоты
	for child in query_container.get_children():
		if child.has_method("_drop_data"): # Проверка, что это слот
			slots.append(child)
	
	# Проверяем, все ли заполнены
	var filled_count = 0
	for slot in slots:
		if slot.current_text != "":
			filled_count += 1
			
	if filled_count < slots.size():
		return # Еще не все заполнено
		
	# Проверяем правильность
	var is_correct = true
	for i in range(slots.size()):
		if slots[i].current_text != data["correct"][i]:
			is_correct = false
			break
			
	if is_correct:
		print("Задание выполнено!")
		next_level()
	else:
		# Можно добавить звук ошибки или покраснение
		print("Ошибка в запросе")

func next_level():
	if current_task_index + 1 < tasks.size():
		load_task(current_task_index + 1)
	else:
		finish_game(true)

func update_progress_ui():
	# Обновляем кружочки (удаляем старые, создаем новые)
	for c in progress_container.get_children(): c.queue_free()
	
	for i in range(tasks.size()):
		var circle = ColorRect.new()
		circle.custom_minimum_size = Vector2(20, 20)
		if i < current_task_index:
			circle.color = Color.GREEN # Выполнено
		elif i == current_task_index:
			circle.color = Color.YELLOW # Текущее
		else:
			circle.color = Color.GRAY # Впереди
		progress_container.add_child(circle)

func finish_game(success: bool):
	get_tree().paused = false # Снимаем паузу
	
	if success:
		print("Лабораторная сдана!")
	else:
		print("Время вышло! Штраф.")
		# Вызов штрафа в GameDirector
		# Предполагается, что GameDirector глобальный или есть к нему доступ
		if GameDirector:
			GameDirector.reduce_time(penalty_time)
	
	# В любом случае отмечаем, что этот квест (лаба) пройден
	if quest_id != "":
		GameState.completed_labs.append(quest_id)
		# Сигнал для дверей/событий, которые ждут выполнения
		GameState.emit_signal("lab_completed", quest_id)
		
	queue_free() # Закрываем мини-игру
	
