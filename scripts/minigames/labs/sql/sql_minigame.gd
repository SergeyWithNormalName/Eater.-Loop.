extends Control

signal task_completed(success: bool)

# --- Настройки ---
@export var time_limit: float = 60.0
@export var penalty_time: float = 15.0
@export var quest_id: String = ""

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
const COLOR_KEYWORD := Color(0.337255, 0.611765, 0.839216)
const STATUS_TEMPLATE := " SQL | UTF-8 | ВРЕМЯ: %.1f сек | LN 1, COL 1"
const MONO_FONT_NAMES := ["JetBrains Mono", "Menlo", "Consolas", "Courier New", "Courier"]

@onready var drag_layer: Control = $DragLayer
@onready var query_container: HBoxContainer = $Layout/MainContent/EditorArea/QueryEditor/QueryFlow
@onready var pool_container: GridContainer = $Layout/MainContent/EditorArea/WordBank/WordGrid
@onready var task_label: Label = $Layout/MainContent/LeftSidebar/TaskInfo/Description
@onready var timer_label: Label = $Footer/StatusLabel

var _mono_font_bold: SystemFont = null

# Загружаем сцены слотов и слов
var slot_scene = preload("res://scenes/minigames/ui/drop_slot.tscn") 
var word_scene = preload("res://scenes/minigames/ui/drag_word.tscn")

func _ready():
	add_to_group("minigame_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_start_lab_music()
	_mono_font_bold = _build_mono_font(600)
	
	# Безопасное включение курсора
	var cm = get_node_or_null("/root/CursorManager")
	if cm:
		cm.request_visible(self)
	
	current_time = time_limit
	_update_status_label()
	load_task(0)

func _process(delta):
	if _is_finished:
		return
	current_time = max(0.0, current_time - delta)
	_update_status_label()
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

func _update_status_label() -> void:
	if timer_label:
		timer_label.text = STATUS_TEMPLATE % max(0.0, current_time)

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
			var keyword = Label.new()
			keyword.text = item
			keyword.add_theme_color_override("font_color", COLOR_KEYWORD)
			if _mono_font_bold:
				keyword.add_theme_font_override("font", _mono_font_bold)
			keyword.add_theme_font_size_override("font_size", 16)
			query_container.add_child(keyword)
			
	# Создание слов для выбора
	for word_text in data["pool"]:
		var word = word_scene.instantiate()
		word.text_value = word_text
		if word.has_method("set_drag_context"):
			word.set_drag_context(drag_layer)
		pool_container.add_child(word)
		
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

func _build_mono_font(weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(MONO_FONT_NAMES)
	font.font_weight = weight
	return font

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
		
		
