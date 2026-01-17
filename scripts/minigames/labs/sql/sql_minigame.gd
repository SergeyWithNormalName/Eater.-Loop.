extends Control

signal task_completed(success: bool)

# --- Настройки ---
var time_limit: float = 60.0
var penalty_time: float = 15.0
var quest_id: String = "" 

# --- Данные заданий ---
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
var _music_pushed: bool = false

const LAB_MUSIC_STREAM := preload("res://audio/MusicEtc/TimerForLabs_DEMO.wav")

@onready var drag_layer: Control = $Content/DragLayer
@onready var query_container: HBoxContainer = $Content/QueryArea
@onready var pool_container: GridContainer = $Content/WordPool
@onready var task_label: Label = $Content/Header/TaskLabel
@onready var timer_label: Label = $Content/Header/TimerLabel
@onready var progress_container: HBoxContainer = $Content/Header/ProgressContainer

# Загружаем сцены слотов и слов
var slot_scene = preload("res://scenes/minigames/ui/drop_slot.tscn") 
var word_scene = preload("res://scenes/minigames/ui/drag_word.tscn")

func _ready():
	add_to_group("minigame_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_start_lab_music()
	
	# Безопасное включение курсора
	var cm = get_node_or_null("/root/CursorManager")
	if cm:
		cm.request_visible(self)
	
	current_time = time_limit
	update_progress_ui()
	load_task(0)

func _process(delta):
	if _is_finished:
		return
	if current_time > 0:
		current_time -= delta
		timer_label.text = "ОСТАЛОСЬ: %.1f сек" % max(0.0, current_time)
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
	
	# Очистка старых элементов
	for child in query_container.get_children(): child.queue_free()
	for child in pool_container.get_children(): child.queue_free()
	
	# Создание слотов запроса
	var correct_index := 0
	for item in data["template"]:
		if item == null:
			# Это слот
			var slot = slot_scene.instantiate()
			# Передаем правильный ответ в слот (важно для вашего drag_slot.gd, так как он проверяет expected_text)
			if correct_index < data["correct"].size():
				slot.expected_text = data["correct"][correct_index]
				correct_index += 1
			
			query_container.add_child(slot)
			# Подписываемся на сигнал падения слова
			if slot.has_signal("word_dropped"):
				slot.word_dropped.connect(check_answer)
		else:
			# Это статический текст
			var static_lbl = Label.new()
			static_lbl.text = item
			query_container.add_child(static_lbl)
			
	# Создание слов для выбора
	for word_text in data["pool"]:
		var word = word_scene.instantiate()
		word.text_value = word_text
		if word.has_method("set_drag_context"):
			word.set_drag_context(drag_layer)
		pool_container.add_child(word)
		
	update_progress_ui()

# Основная функция проверки
func check_answer(_arg = null):
	# Ждем 1 кадр, чтобы переменные в слоте успели обновиться после сигнала
	await get_tree().process_frame
	
	if _is_finished: return

	var data = tasks[current_task_index]
	var slots = []
	
	# --- ВАЖНОЕ ИСПРАВЛЕНИЕ: Ищем слоты по методу "set_word", который есть в drag_slot.gd ---
	for child in query_container.get_children():
		if not child.is_queued_for_deletion() and child.has_method("set_word"):
			slots.append(child)
	
	var correct_matches = 0
	var filled_count = 0
	
	# Проверяем содержимое слотов
	for i in range(slots.size()):
		var slot = slots[i]
		var slot_text = ""
		
		if "current_text" in slot:
			slot_text = slot.current_text
		
		if slot_text != "":
			filled_count += 1
		
		# Сравниваем с правильным ответом
		if i < data["correct"].size():
			if slot_text == data["correct"][i]:
				correct_matches += 1
	
	# Отладка в консоль (поможет понять, что происходит)
	print("Проверка: Слотов %d, Заполнено %d, Верно %d" % [slots.size(), filled_count, correct_matches])
	
	# Если ВСЕ слоты заполнены И ВСЕ верны — победа
	if correct_matches == slots.size() and slots.size() > 0:
		print(">> Уровень пройден!")
		next_level()
	elif filled_count == slots.size():
		# Все заполнили, но есть ошибки
		print(">> Ошибка в ответе")

func next_level():
	if current_task_index + 1 < tasks.size():
		load_task(current_task_index + 1)
	else:
		finish_game(true)

func update_progress_ui():
	for c in progress_container.get_children(): c.queue_free()
	for i in range(tasks.size()):
		var circle = ColorRect.new()
		circle.custom_minimum_size = Vector2(20, 20)
		if i < current_task_index:
			circle.color = Color.GREEN 
		elif i == current_task_index:
			circle.color = Color.YELLOW 
		else:
			circle.color = Color.GRAY 
		progress_container.add_child(circle)

func finish_game(success: bool):
	if _is_finished:
		return
	_is_finished = true
	_restore_lab_music()
	get_tree().paused = false 
	task_completed.emit(success)
	
	if success:
		print("Лабораторная выполнена!")
	else:
		print("Время вышло! Штраф.")
		var gd = get_node_or_null("/root/GameDirector")
		if gd:
			gd.reduce_time(penalty_time)

	if success and quest_id != "":
		var gs = get_node_or_null("/root/GameState")
		if gs and not gs.completed_labs.has(quest_id):
			gs.completed_labs.append(quest_id)
			gs.emit_signal("lab_completed", quest_id)

	queue_free()

func _start_lab_music() -> void:
	if MusicManager == null:
		return
	if _music_pushed:
		return
	_ensure_lab_music_loop()
	MusicManager.push_music(LAB_MUSIC_STREAM)
	_music_pushed = true

func _restore_lab_music() -> void:
	if MusicManager == null:
		return
	if not _music_pushed:
		return
	MusicManager.pop_music()
	_music_pushed = false

func _ensure_lab_music_loop() -> void:
	var stream: AudioStream = LAB_MUSIC_STREAM
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return
	if stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = true
		return
	if stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		mp3.loop = true

func _exit_tree() -> void:
	_restore_lab_music()
	var cm = get_node_or_null("/root/CursorManager")
	if cm:
		cm.release_visible(self)
		
		
