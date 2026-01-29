extends Control

signal task_completed(success: bool)

# --- Настройки ---
@export var time_limit: float = 60.0
@export var penalty_time: float = 15.0

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

const LAB_MUSIC_STREAM := preload("res://music/TimerForLabs_DEMO.wav")
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
var slot_scene = preload("res://levels/minigames/ui/drop_slot.tscn") 
var word_scene = preload("res://levels/minigames/ui/drag_word.tscn")

func _ready():
	add_to_group("minigame_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mono_font_bold = _build_mono_font(600)

	_start_minigame_session()
	load_task(0)

func _update_status_label() -> void:
	if timer_label:
		timer_label.text = STATUS_TEMPLATE % max(0.0, current_time)

func load_task(index):
	if index < 0 or index >= tasks.size():
		push_warning("SqlMinigame: неверный индекс задания %d." % index)
		return
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
	
	# Если ВСЕ слоты заполнены И ВСЕ верны — победа
	if correct_matches == slots.size() and slots.size() > 0:
		next_level()

func next_level():
	if current_task_index + 1 < tasks.size():
		load_task(current_task_index + 1)
	else:
		finish_game(true)

func finish_game(success: bool):
	if _is_finished:
		return
	_is_finished = true
	if MinigameController:
		MinigameController.finish_minigame(self, success)
	task_completed.emit(success)
	
	if success:
		print("Лабораторная выполнена!")
	else:
		print("Время вышло! Штраф.")
		var gd = get_node_or_null("/root/GameDirector")
		if gd:
			gd.reduce_time(penalty_time)

	if success:
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.has_method("mark_lab_completed"):
			gs.mark_lab_completed()

	queue_free()

func _start_minigame_session() -> void:
	if MinigameController == null:
		current_time = time_limit
		_update_status_label()
		return
	_ensure_lab_music_loop()
	MinigameController.start_minigame(self, {
		"pause_game": true,
		"enable_gamepad_cursor": true,
		"time_limit": time_limit,
		"music_stream": LAB_MUSIC_STREAM,
		"music_fade_time": 0.0,
		"auto_finish_on_timeout": false
	})
	current_time = time_limit
	_update_status_label()
	MinigameController.minigame_time_updated.connect(_on_time_updated)
	MinigameController.minigame_time_expired.connect(_on_time_expired)

func _on_time_updated(minigame: Node, time_left: float, _time_limit: float) -> void:
	if minigame != self:
		return
	current_time = time_left
	_update_status_label()

func _on_time_expired(minigame: Node) -> void:
	if minigame != self:
		return
	finish_game(false)

func _build_mono_font(weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(MONO_FONT_NAMES)
	font.font_weight = weight
	return font

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
	if MinigameController:
		if MinigameController.minigame_time_updated.is_connected(_on_time_updated):
			MinigameController.minigame_time_updated.disconnect(_on_time_updated)
		if MinigameController.minigame_time_expired.is_connected(_on_time_expired):
			MinigameController.minigame_time_expired.disconnect(_on_time_expired)
		if MinigameController.is_active(self):
			MinigameController.finish_minigame(self, false)
		
		
