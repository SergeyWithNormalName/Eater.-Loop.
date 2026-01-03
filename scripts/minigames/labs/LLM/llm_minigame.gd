extends Control

signal task_completed(success: bool)

@export var time_limit: float = 60.0
@export var penalty_time: float = 15.0
@export var quest_id: String = ""
@export var progress_per_click: float = 0.1

var current_time: float = 0.0
var _progress: float = 0.0
var _is_finished: bool = false
var _base_viewport: Vector2
var _content_base_pos: Vector2
var _content_base_scale: Vector2

@onready var content: Control = $Content
@onready var background: ColorRect = $Content/Background
@onready var title_label: Label = $Content/Header/TitleLabel
@onready var timer_label: Label = $Content/Header/TimerLabel
@onready var progress_bar: ProgressBar = $Content/Body/ProgressBar
@onready var generate_button: Button = $Content/Body/GenerateButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	current_time = time_limit
	
	_base_viewport = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	)
	content.size = _base_viewport
	background.custom_minimum_size = _base_viewport
	_content_base_pos = content.position
	_content_base_scale = content.scale
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	
	title_label.text = "Нейросеть глубокий Сик"
	_update_progress_ui()
	generate_button.pressed.connect(_on_generate_pressed)

func _process(delta: float) -> void:
	if _is_finished:
		return
	
	current_time -= delta
	timer_label.text = "ОСТАЛОСЬ: %.1f сек" % max(current_time, 0.0)
	if current_time <= 0.0:
		finish_game(false)
		return
	
	_handle_gamepad_cursor(delta)

func _input(event: InputEvent) -> void:
	if _is_finished:
		return
	
	if _is_grab_pressed(event):
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered == generate_button:
			_on_generate_pressed()

func _on_generate_pressed() -> void:
	if _is_finished:
		return
	
	_progress = clamp(_progress + progress_per_click, 0.0, 1.0)
	_update_progress_ui()
	if _progress >= 1.0:
		finish_game(true)

func _update_progress_ui() -> void:
	progress_bar.value = _progress * 100.0

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

func _update_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if _base_viewport.x <= 0.0 or _base_viewport.y <= 0.0:
		return
	
	var scale_factor: float = min(viewport_size.x / _base_viewport.x, viewport_size.y / _base_viewport.y)
	var layout_offset: Vector2 = (viewport_size - _base_viewport * scale_factor) * 0.5
	content.position = layout_offset + _content_base_pos * scale_factor
	content.scale = _content_base_scale * scale_factor

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
	return event.is_action_pressed("mg_grab") or event.is_action_pressed("mg_grap")
