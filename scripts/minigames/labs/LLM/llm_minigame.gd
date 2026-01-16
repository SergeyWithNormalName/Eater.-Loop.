extends Control

signal task_completed(success: bool)

## Лимит времени на мини-игру.
@export var time_limit: float = 60.0
## Штраф по времени за ошибку.
@export var penalty_time: float = 15.0
## ID квеста для отметки выполнения.
@export var quest_id: String = ""
## Прогресс за одно нажатие.
@export var progress_per_click: float = 0.1

@export_group("Кулдаун генерации")
## Минимальная пауза между нажатиями (сек).
@export_range(0.0, 10.0, 0.05) var click_cooldown_min: float = 0.6
## Максимальная пауза между нажатиями (сек).
@export_range(0.0, 10.0, 0.05) var click_cooldown_max: float = 1.2

var current_time: float = 0.0
var _progress: float = 0.0
var _is_finished: bool = false
var _prev_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _cooldown_remaining: float = 0.0
var _cooldown_duration: float = 0.0
var _generate_base_text: String = ""
var _rng := RandomNumberGenerator.new()

@onready var title_label: Label = $Content/Header/TitleLabel
@onready var timer_label: Label = $Content/Header/TimerLabel
@onready var progress_bar: ProgressBar = $Content/Body/ProgressBar
@onready var generate_button: Button = $Content/Body/GenerateButton

func _ready() -> void:
	add_to_group("minigame_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	current_time = time_limit
	_rng.randomize()
	
	title_label.text = "Нейросеть глубокий Сик"
	_update_progress_ui()
	_generate_base_text = generate_button.text
	_update_generate_button()
	generate_button.pressed.connect(_on_generate_pressed)

func _process(delta: float) -> void:
	if _is_finished:
		return
	
	current_time -= delta
	timer_label.text = "ОСТАЛОСЬ: %.1f сек" % max(current_time, 0.0)
	if current_time <= 0.0:
		finish_game(false)
		return

	_update_cooldown(delta)
	
	_handle_gamepad_cursor(delta)

func _input(event: InputEvent) -> void:
	if _is_finished:
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		return
	
	if _is_grab_pressed(event):
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered == generate_button:
			_on_generate_pressed()

func _on_generate_pressed() -> void:
	if _is_finished:
		return
	if _cooldown_remaining > 0.0:
		return
	
	_progress = clamp(_progress + progress_per_click, 0.0, 1.0)
	_update_progress_ui()
	if _progress >= 1.0:
		finish_game(true)
		return

	_start_click_cooldown()

func _update_progress_ui() -> void:
	progress_bar.value = _progress * 100.0

func _start_click_cooldown() -> void:
	var min_cd: float = min(click_cooldown_min, click_cooldown_max)
	var max_cd: float = max(click_cooldown_min, click_cooldown_max)
	min_cd = maxf(0.0, min_cd)
	max_cd = maxf(0.0, max_cd)
	if max_cd <= 0.0:
		_cooldown_remaining = 0.0
		_cooldown_duration = 0.0
		_update_generate_button()
		return
	_cooldown_duration = _rng.randf_range(min_cd, max_cd)
	_cooldown_remaining = _cooldown_duration
	_update_generate_button()

func _update_cooldown(delta: float) -> void:
	if _cooldown_remaining <= 0.0:
		return
	_cooldown_remaining = max(0.0, _cooldown_remaining - delta)
	_update_generate_button()

func _update_generate_button() -> void:
	if generate_button == null:
		return
	var on_cooldown := _cooldown_remaining > 0.0
	generate_button.disabled = on_cooldown or _is_finished
	if on_cooldown:
		generate_button.text = "Ждите: %.1f сек" % _cooldown_remaining
	else:
		generate_button.text = _generate_base_text

func finish_game(success: bool) -> void:
	if _is_finished:
		return
	_is_finished = true
	get_tree().paused = false
	task_completed.emit(success)
	
	if not success:
		if GameDirector:
			GameDirector.reduce_time(penalty_time)
	
	if quest_id != "":
		if not GameState.completed_labs.has(quest_id):
			GameState.completed_labs.append(quest_id)
			GameState.emit_signal("lab_completed", quest_id)
	
	queue_free()

func _exit_tree() -> void:
	Input.set_mouse_mode(_prev_mouse_mode)

func _handle_gamepad_cursor(delta: float) -> void:
	var joy_vector = Input.get_vector("mg_cursor_left", "mg_cursor_right", "mg_cursor_up", "mg_cursor_down")
	if joy_vector.length() > 0.1:
		var current_mouse = get_viewport().get_mouse_position()
		var new_pos = current_mouse + joy_vector * 800.0 * delta
		var screen_rect = get_viewport().get_visible_rect().size
		new_pos.x = clamp(new_pos.x, 0, screen_rect.x)
		new_pos.y = clamp(new_pos.y, 0, screen_rect.y)
		get_viewport().warp_mouse(new_pos)

func _is_grab_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("mg_grab")
