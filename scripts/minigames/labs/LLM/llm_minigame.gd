extends Control

# --- СИГНАЛЫ ---
signal task_completed(success: bool)

# --- НАСТРОЙКИ ---
@export_group("Game Logic")
## Лимит времени на мини-игру (сек).
@export var time_limit: float = 60.0
## Штраф по времени за провал (сек).
@export var penalty_time: float = 15.0
## ID квеста для LogicManager/GameState.
@export var quest_id: String = ""
## Насколько заполняется прогресс за один клик (0.1 = 10%).
@export var progress_per_click: float = 0.1

@export_group("Cooldowns")
## Минимальная пауза "Думает..." (сек).
@export_range(0.0, 5.0) var click_cooldown_min: float = 0.6
## Максимальная пауза "Думает..." (сек).
@export_range(0.0, 5.0) var click_cooldown_max: float = 1.2

# --- ВНУТРЕННИЕ ПЕРЕМЕННЫЕ ---
var current_time: float = 0.0
var _progress: float = 0.0
var _is_finished: bool = false
var _cooldown_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()

# Тексты для кнопки (имитация состояний)
const TEXT_IDLE = "   Сгенерировать отчёт"
const TEXT_PROCESSING = "   Подождите... "
const TEXT_DONE = "   Отчёт готов!"

# --- ССЫЛКИ НА УЗЛЫ (Nodes) ---
@onready var timer_label: Label = $GameTimerLabel
@onready var generate_button: Button = $CenterContainer/InteractionArea/InputButton
@onready var progress_bar: ProgressBar = $CenterContainer/InteractionArea/InputButton/ProgressBar
@onready var arrow_icon: Control = $CenterContainer/InteractionArea/InputButton/IconArrow

func _ready() -> void:
	add_to_group("minigame_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	if get_tree().root.has_node("CursorManager"):
		var cursor_mgr = get_tree().root.get_node("CursorManager")
		if cursor_mgr.has_method("request_visible"):
			cursor_mgr.request_visible(self)

	current_time = time_limit
	_rng.randomize()

	_update_ui_state()
	generate_button.pressed.connect(_on_generate_pressed)

func _process(delta: float) -> void:
	if _is_finished:
		return

	current_time -= delta
	var mins = floor(current_time / 60)
	var secs = int(current_time) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]

	if current_time <= 0.0:
		finish_game(false)
		return

	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_cooldown_finished()
		else:
			generate_button.text = TEXT_PROCESSING + "%.1f сек" % _cooldown_remaining

	_handle_gamepad_cursor(delta)

func _on_generate_pressed() -> void:
	if _is_finished:
		return
	if _cooldown_remaining > 0.0:
		return

	_progress = clamp(_progress + progress_per_click, 0.0, 1.0)

	var tween = create_tween()
	tween.tween_property(progress_bar, "value", _progress * 100.0, 0.1).set_trans(Tween.TRANS_SINE)

	if _progress >= 1.0:
		finish_game(true)
		return

	_start_click_cooldown()

func _start_click_cooldown() -> void:
	var duration = _rng.randf_range(click_cooldown_min, click_cooldown_max)
	_cooldown_remaining = duration

	generate_button.disabled = true
	generate_button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if arrow_icon:
		arrow_icon.modulate = Color(0.3, 0.3, 0.3)

func _cooldown_finished() -> void:
	_cooldown_remaining = 0.0
	generate_button.disabled = false
	generate_button.text = TEXT_IDLE
	generate_button.remove_theme_color_override("font_color")
	if arrow_icon:
		arrow_icon.modulate = Color(1, 1, 1)

func _update_ui_state() -> void:
	progress_bar.value = _progress * 100.0
	generate_button.text = TEXT_IDLE

func finish_game(success: bool) -> void:
	if _is_finished:
		return
	_is_finished = true

	if success:
		generate_button.text = TEXT_DONE
		var style = generate_button.get_theme_stylebox("normal").duplicate()
		style.border_color = Color.GREEN
		generate_button.add_theme_stylebox_override("normal", style)
	else:
		_shake_button()

	await get_tree().create_timer(0.5).timeout

	get_tree().paused = false
	task_completed.emit(success)

	if not success:
		if get_tree().root.has_node("GameDirector"):
			get_tree().root.get_node("GameDirector").reduce_time(penalty_time)

	if success and quest_id != "":
		if get_tree().root.has_node("GameState"):
			var gs = get_tree().root.get_node("GameState")
			if not gs.completed_labs.has(quest_id):
				gs.completed_labs.append(quest_id)
				gs.emit_signal("lab_completed", quest_id)

	queue_free()

func _exit_tree() -> void:
	if get_tree().root.has_node("CursorManager"):
		var cursor_mgr = get_tree().root.get_node("CursorManager")
		if cursor_mgr.has_method("release_visible"):
			cursor_mgr.release_visible(self)

func _shake_button() -> void:
	var tween = create_tween()
	var orig_pos = generate_button.position.x
	for i in range(5):
		tween.tween_property(generate_button, "position:x", orig_pos + 5, 0.05)
		tween.tween_property(generate_button, "position:x", orig_pos - 5, 0.05)
	tween.tween_property(generate_button, "position:x", orig_pos, 0.05)

func _handle_gamepad_cursor(delta: float) -> void:
	var joy_vector = Input.get_vector("mg_cursor_left", "mg_cursor_right", "mg_cursor_up", "mg_cursor_down")
	if joy_vector.length() > 0.1:
		var current_mouse = get_viewport().get_mouse_position()
		var new_pos = current_mouse + joy_vector * 800.0 * delta
		var screen_rect = get_viewport().get_visible_rect().size
		new_pos.x = clamp(new_pos.x, 0, screen_rect.x)
		new_pos.y = clamp(new_pos.y, 0, screen_rect.y)
		get_viewport().warp_mouse(new_pos)

func _input(event: InputEvent) -> void:
	if _is_finished:
		return
	if event.is_action_pressed("mg_grab"):
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered == generate_button:
			_on_generate_pressed()
