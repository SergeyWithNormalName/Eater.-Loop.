extends Control

signal task_completed(success: bool)

@export var time_limit: float = 60.0
@export var penalty_time: float = 15.0

var tasks = [
	{
		"description": "Удалите таблицу друзей и одновременно добавьте в неё борщ. Да, одновременно.",
		"template": ["DROP", "TABLE", null, ";", null, "INTO", null, "VALUES", "(", null, ")"],
		"correct": ["Friends", "INSERT", "Friends", "'БОРЩ'"],
		"pool": ["DROP", "Friends", "DELETE", "FRI3NDS", "'БОРЩ'", "PIZZA", "SELECT", "NULL"]
	},
	{
		"description": "Найдите всех должников, чей долг > бесконечности и < -1 и = maybe.",
		"template": ["SELECT", "*", "FROM", null, "WHERE", null, ">", "INF", "AND", null, "<", "-1"],
		"correct": ["Students", "debt", "ghost_debt"],
		"pool": ["Students", "debt", "id", "∞", "FALSE", "0", "NAN"]
	},
	{
		"description": "Соберите запрос, который валиден только по пятницам в 25:61.",
		"template": [null, "TABLE", "Reality", ";", "UPDATE", null, "SET", null, "=", null],
		"correct": ["ALTER", "Lunch", "taste", "'вчерашние_носки'"],
		"pool": ["ALTER", "DINNER", "taste", "'pizza'", "DROP", "WHERE", "404"]
	}
]

var current_task_index = 0
var current_time = 0.0
var _is_finished: bool = false
var _gamepad_selected_word: String = ""
var _rng := RandomNumberGenerator.new()
var _glitch_tick := 0.0

const LAB_MUSIC_STREAM := preload("res://music/TimerForLabs_DEMO.wav")
const COLOR_KEYWORD := Color(0.337255, 0.611765, 0.839216)
const MONO_FONT_NAMES := ["JetBrains Mono", "Menlo", "Consolas", "Courier New", "Courier"]
const STATUS_GLITCH_VARIANTS := [
	" SQL | UTF-8 | ВРЕМЯ: %.1f сек | LN 1, COL 1",
	" SQЛ | ПАКЕТЫ ПОТЕРЯНЫ | %.1f",
	" DB PANIC %.1f // friends table missing",
	" SQLn't | ERROR %.1f",
	" LN ??? COL ??? T-%.1f"
]
const TASK_GLITCH_SUFFIXES := ["", " [ОШИБКА 0xF00D]", " [задание мутирует]", " [подсказки лгут]", " [таблица сбежала]"]

@onready var drag_layer: Control = $DragLayer
@onready var query_container: HBoxContainer = $Layout/MainContent/EditorArea/QueryEditor/QueryFlow
@onready var pool_container: GridContainer = $Layout/MainContent/EditorArea/WordBank/WordGrid
@onready var task_label: Label = $Layout/MainContent/LeftSidebar/TaskInfo/Description
@onready var timer_label: Label = $Footer/StatusLabel

var _mono_font_bold: SystemFont = null

var slot_scene = preload("res://levels/minigames/ui/drop_slot.tscn")
var word_scene = preload("res://levels/minigames/ui/drag_word.tscn")

func _ready() -> void:
	add_to_group("minigame_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_mono_font_bold = _build_mono_font(600)

	_start_minigame_session()
	load_task(0)
	_register_gamepad_scheme()

func _process(delta: float) -> void:
	if _is_finished:
		return
	_glitch_tick -= delta
	if _glitch_tick <= 0.0:
		_glitch_tick = _rng.randf_range(0.15, 0.45)
		_apply_visual_glitch_tick()

func _update_status_label() -> void:
	if timer_label:
		timer_label.text = _pick(STATUS_GLITCH_VARIANTS) % max(0.0, current_time)

func load_task(index: int) -> void:
	if index < 0 or index >= tasks.size():
		push_warning("SqlGlitchMinigame: неверный индекс задания %d." % index)
		return
	current_task_index = index
	_gamepad_selected_word = ""
	var data = tasks[index]
	task_label.text = _make_glitch_task_text(data["description"])

	for child in query_container.get_children():
		child.queue_free()
	for child in pool_container.get_children():
		child.queue_free()

	var correct_index := 0
	for item in data["template"]:
		if item == null:
			var slot = slot_scene.instantiate()
			if correct_index < data["correct"].size():
				slot.expected_text = data["correct"][correct_index]
				correct_index += 1
			query_container.add_child(slot)
			if slot.has_signal("word_dropped"):
				slot.word_dropped.connect(check_answer)
		else:
			var keyword = Label.new()
			keyword.text = item
			keyword.add_theme_color_override("font_color", COLOR_KEYWORD)
			if _mono_font_bold:
				keyword.add_theme_font_override("font", _mono_font_bold)
			keyword.add_theme_font_size_override("font_size", 16)
			query_container.add_child(keyword)

	for word_text in data["pool"]:
		var word = word_scene.instantiate()
		word.text_value = word_text
		if word.has_method("set_drag_context"):
			word.set_drag_context(drag_layer)
		pool_container.add_child(word)

	_register_gamepad_scheme()

func check_answer(_arg = null) -> void:
	await get_tree().process_frame
	if _is_finished:
		return

	var data = tasks[current_task_index]
	var slots: Array = []
	for child in query_container.get_children():
		if not child.is_queued_for_deletion() and child.has_method("set_word"):
			slots.append(child)

	var correct_matches := 0
	for i in range(slots.size()):
		var slot = slots[i]
		var slot_text := ""
		if "current_text" in slot:
			slot_text = slot.current_text
		if i < data["correct"].size() and slot_text == data["correct"][i]:
			correct_matches += 1

	if correct_matches == slots.size() and slots.size() > 0:
		next_level()

func next_level() -> void:
	if current_task_index + 1 < tasks.size():
		load_task(current_task_index + 1)
	else:
		finish_game(true)

func finish_game(success: bool) -> void:
	if _is_finished:
		return
	_is_finished = true
	if MinigameController:
		MinigameController.finish_minigame_with_fade(self, success, func():
			task_completed.emit(success)
			if not success:
				var gd = get_node_or_null("/root/GameDirector")
				if gd:
					gd.reduce_time(penalty_time)
			if success:
				var gs = get_node_or_null("/root/GameState")
				if gs and gs.has_method("mark_lab_completed"):
					gs.mark_lab_completed()
			queue_free()
		)
		return
	task_completed.emit(success)
	queue_free()

func _start_minigame_session() -> void:
	if MinigameController == null:
		current_time = time_limit
		_update_status_label()
		return
	_ensure_lab_music_loop()
	if not MinigameController.is_active(self):
		var settings := MinigameSettings.new()
		settings.pause_game = false
		settings.show_mouse_cursor = true
		settings.block_player_movement = true
		settings.time_limit = time_limit
		settings.music_stream = LAB_MUSIC_STREAM
		settings.music_fade_time = 0.0
		settings.auto_finish_on_timeout = false
		MinigameController.start_minigame(self, settings)
	current_time = time_limit
	_update_status_label()
	if not MinigameController.minigame_time_updated.is_connected(_on_time_updated):
		MinigameController.minigame_time_updated.connect(_on_time_updated)
	if not MinigameController.minigame_time_expired.is_connected(_on_time_expired):
		MinigameController.minigame_time_expired.connect(_on_time_expired)

func _on_time_updated(minigame: Node, time_left: float, _time_limit: float) -> void:
	if minigame != self:
		return
	current_time = time_left
	_update_status_label()
	if _rng.randf() < 0.35:
		task_label.text = _make_glitch_task_text(tasks[current_task_index]["description"])

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
		MinigameController.clear_gamepad_scheme(self)
		if MinigameController.minigame_time_updated.is_connected(_on_time_updated):
			MinigameController.minigame_time_updated.disconnect(_on_time_updated)
		if MinigameController.minigame_time_expired.is_connected(_on_time_expired):
			MinigameController.minigame_time_expired.disconnect(_on_time_expired)
		if MinigameController.is_active(self):
			MinigameController.finish_minigame(self, false)

func _register_gamepad_scheme() -> void:
	if MinigameController == null:
		return
	MinigameController.set_gamepad_scheme(self, {
		"mode": "pick_place",
		"source_provider": Callable(self, "_get_gamepad_source_nodes"),
		"target_provider": Callable(self, "_get_gamepad_target_nodes"),
		"on_pick": Callable(self, "_on_gamepad_pick"),
		"on_cancel_pick": Callable(self, "_on_gamepad_cancel_pick"),
		"on_place": Callable(self, "_on_gamepad_place"),
		"on_placed": Callable(self, "_on_gamepad_placed"),
		"on_secondary": Callable(self, "_on_gamepad_secondary"),
		"hints": {
			"confirm": "Выбор / вставка",
			"cancel": "Выход",
			"secondary": "Очистить слот",
			"tab_left": "Секция",
			"tab_right": "Секция"
		}
	})

func _get_gamepad_source_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for child in pool_container.get_children():
		if child == null or child.is_queued_for_deletion():
			continue
		if child is Button:
			nodes.append(child)
	return nodes

func _get_gamepad_target_nodes() -> Array[Node]:
	var slots := _get_all_gamepad_target_slots()
	if _gamepad_selected_word == "":
		return slots
	var nodes: Array[Node] = []
	for slot in slots:
		if slot.has_method("can_accept_word") and bool(slot.call("can_accept_word", _gamepad_selected_word)):
			nodes.append(slot)
	return nodes

func _get_all_gamepad_target_slots() -> Array[Node]:
	var nodes: Array[Node] = []
	for child in query_container.get_children():
		if child == null or child.is_queued_for_deletion():
			continue
		if child.has_method("set_word") and child.has_method("can_accept_word"):
			nodes.append(child)
	return nodes

func _on_gamepad_pick(source: Node, _context: Dictionary) -> void:
	_gamepad_selected_word = _extract_word_from_source(source)

func _on_gamepad_cancel_pick(_source: Node, _context: Dictionary) -> void:
	_gamepad_selected_word = ""

func _on_gamepad_place(source: Node, target: Node, _context: Dictionary) -> bool:
	if source == null or target == null:
		return false
	if not target.has_method("can_accept_word") or not target.has_method("set_word"):
		return false
	var word_text := _extract_word_from_source(source)
	if word_text == "":
		return false
	if not target.can_accept_word(word_text):
		return false
	target.set_word(word_text)
	_gamepad_selected_word = ""
	check_answer()
	return true

func _on_gamepad_placed(_source: Node, _target: Node, _context: Dictionary) -> void:
	_gamepad_selected_word = ""

func _on_gamepad_secondary(active: Node, _context: Dictionary) -> bool:
	if active == null:
		return false
	if not active.has_method("clear_word"):
		return false
	active.clear_word()
	check_answer()
	return true

func _extract_word_from_source(source: Node) -> String:
	if source == null:
		return ""
	if "text_value" in source:
		return String(source.text_value)
	if source is Button:
		return String((source as Button).text)
	return ""

func _apply_visual_glitch_tick() -> void:
	if task_label:
		task_label.text = _make_glitch_task_text(tasks[current_task_index]["description"])
	for child in pool_container.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		if _rng.randf() < 0.58:
			button.text = _corrupt_word(button.text)
		if _rng.randf() < 0.15:
			button.position += Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-6, 6))
	# Иногда очищаем один случайный слот, чтобы всё "ломалось"
	if _rng.randf() < 0.28:
		var slots := _get_all_gamepad_target_slots()
		if not slots.is_empty():
			var slot = slots[_rng.randi_range(0, slots.size() - 1)]
			if slot.has_method("clear_word"):
				slot.clear_word()
	_update_status_label()

func _make_glitch_task_text(base_text: String) -> String:
	return "%s%s" % [base_text, _pick(TASK_GLITCH_SUFFIXES)]

func _corrupt_word(word: String) -> String:
	if word.length() <= 1:
		return word
	var mode := _rng.randi_range(0, 4)
	if mode == 0:
		return "%s?" % word
	if mode == 1:
		return word.to_upper() if _rng.randf() < 0.5 else word.to_lower()
	if mode == 2:
		return word.replace("E", "3").replace("O", "0")
	if mode == 3:
		return "%s%s" % [word.substr(1), word.substr(0, 1)]
	return "%s_" % word

func _pick(list: Array[String]) -> String:
	if list.is_empty():
		return ""
	return list[_rng.randi_range(0, list.size() - 1)]
