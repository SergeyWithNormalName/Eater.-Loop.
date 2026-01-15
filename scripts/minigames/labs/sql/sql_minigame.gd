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
var _is_finished: bool = false
var _prev_mouse_mode: int = Input.MOUSE_MODE_VISIBLE

@onready var drag_layer: Control = $Content/DragLayer
@onready var query_container: HBoxContainer = $Content/QueryArea
@onready var pool_container: GridContainer = $Content/WordPool
@onready var task_label: Label = $Content/Header/TaskLabel
@onready var timer_label: Label = $Content/Header/TimerLabel
@onready var progress_container: HBoxContainer = $Content/Header/ProgressContainer

# Префабы (загрузи их или создай кодом, здесь пример кодом для простоты, 
# но лучше назначить .tscn файлы в инспекторе)
var slot_scene = preload("res://scenes/minigames/ui/drop_slot.tscn") 
var word_scene = preload("res://scenes/minigames/ui/drag_word.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ставим игру на паузу
	get_tree().paused = true
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	current_time = time_limit

	update_progress_ui()
	load_task(0)

func _process(delta):
	if _is_finished:
		return
	if current_time > 0:
		current_time -= delta
		timer_label.text = "ОСТАЛОСЬ: %.1f сек" % current_time
		if current_time <= 0:
			finish_game(false)
	
	_handle_gamepad_cursor(delta)

func _handle_gamepad_cursor(delta: float) -> void:
	var joy_vector = Input.get_vector("mg_cursor_left", "mg_cursor_right", "mg_cursor_up", "mg_cursor_down")
	if joy_vector.length() > 0.1:
		var current_mouse = get_viewport().get_mouse_position()
		var new_pos = current_mouse + joy_vector * 800.0 * delta
		var screen_rect = get_viewport().get_visible_rect().size
		new_pos.x = clamp(new_pos.x, 0, screen_rect.x)
		new_pos.y = clamp(new_pos.y, 0, screen_rect.y)
		get_viewport().warp_mouse(new_pos)

func load_task(index):
	current_task_index = index
	var data = tasks[index]
	
	task_label.text = data["description"]
	
	# Очистка старого
	for child in query_container.get_children(): child.queue_free()
	for child in pool_container.get_children(): child.queue_free()
	
	# Генерация слотов запроса
	var correct_index := 0
	for item in data["template"]:
		if item == null:
			# Это пустой слот для перетаскивания
			var slot = slot_scene.instantiate()
			if correct_index < data["correct"].size():
				slot.expected_text = data["correct"][correct_index]
				correct_index += 1
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
		if word.has_method("set_drag_context"):
			word.set_drag_context(drag_layer)
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
	if _is_finished:
		return
	_is_finished = true
	get_tree().paused = false # Снимаем паузу
	task_completed.emit(success)
	
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
		if not GameState.completed_labs.has(quest_id):
			GameState.completed_labs.append(quest_id)
			# Сигнал для дверей/событий, которые ждут выполнения
			GameState.emit_signal("lab_completed", quest_id)
		
	queue_free() # Закрываем мини-игру

func _exit_tree() -> void:
	Input.set_mouse_mode(_prev_mouse_mode)
	
