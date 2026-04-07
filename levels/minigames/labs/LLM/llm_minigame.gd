extends "res://levels/minigames/labs/timed_lab_minigame_base.gd"

# --- НАСТРОЙКИ ---
@export_group("Game Logic")
## Насколько заполняется прогресс за один клик (0.1 = 10%).
@export var progress_per_click: float = 0.1

@export_group("Cooldowns")
## Минимальная пауза "Думает..." (сек).
@export_range(0.0, 5.0) var click_cooldown_min: float = 0.6
## Максимальная пауза "Думает..." (сек).
@export_range(0.0, 5.0) var click_cooldown_max: float = 1.2

# --- ВНУТРЕННИЕ ПЕРЕМЕННЫЕ ---
var _progress: float = 0.0
var _is_finished: bool = false
var _cooldown_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()

# Тексты для кнопки (имитация состояний)
const TEXT_IDLE = "   Сгенерировать отчёт"
const TEXT_PROCESSING_WITH_TIME = "   Подождите... %.1f сек"
const TEXT_DONE = "   Отчёт готов!"

# --- ССЫЛКИ НА УЗЛЫ (Nodes) ---
@onready var timer_label: Label = $GameTimerLabel
@onready var generate_button: Button = $CenterContainer/InteractionArea/InputButton
@onready var progress_bar: ProgressBar = $CenterContainer/InteractionArea/InputButton/ProgressBar
@onready var arrow_icon: Control = $CenterContainer/InteractionArea/InputButton/IconArrow

func _ready() -> void:
	start_timed_lab_session(Callable(self, "_on_time_updated"), Callable(self, "_on_time_expired"))

	_rng.randomize()

	_update_ui_state()
	generate_button.pressed.connect(_on_generate_pressed)
	_register_gamepad_scheme()
	_update_timer_label()

func _process(delta: float) -> void:
	if _is_finished:
		return

	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_cooldown_finished()
		else:
			generate_button.text = tr(TEXT_PROCESSING_WITH_TIME) % _cooldown_remaining

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
	generate_button.text = tr(TEXT_IDLE)
	generate_button.remove_theme_color_override("font_color")
	if arrow_icon:
		arrow_icon.modulate = Color(1, 1, 1)

func _update_ui_state() -> void:
	progress_bar.value = _progress * 100.0
	generate_button.text = tr(TEXT_IDLE)

func finish_game(success: bool) -> void:
	if _is_finished:
		return
	_is_finished = true
	if finish_timed_lab_with_fade(success, Callable(self, "_finalize_finish").bind(success)):
		return

	_finalize_finish(success)

func _finalize_finish(success: bool) -> void:
	if success:
		generate_button.text = tr(TEXT_DONE)
		var style = generate_button.get_theme_stylebox("normal").duplicate()
		style.border_color = Color.GREEN
		generate_button.add_theme_stylebox_override("normal", style)
	else:
		_shake_button()

	get_tree().create_timer(0.5).timeout.connect(Callable(self, "_complete_finish").bind(success), Object.CONNECT_ONE_SHOT)

func _complete_finish(success: bool) -> void:
	task_completed.emit(success)
	apply_standard_lab_outcome(success)
	queue_free()

func _exit_tree() -> void:
	cleanup_timed_lab(Callable(self, "_on_time_updated"), Callable(self, "_on_time_expired"))

func _shake_button() -> void:
	var tween = create_tween()
	var orig_pos = generate_button.position.x
	for i in range(5):
		tween.tween_property(generate_button, "position:x", orig_pos + 5, 0.05)
		tween.tween_property(generate_button, "position:x", orig_pos - 5, 0.05)
	tween.tween_property(generate_button, "position:x", orig_pos, 0.05)

func _on_time_updated(minigame: Node, time_left: float, _limit: float) -> void:
	if minigame != self:
		return
	current_time = time_left
	_update_timer_label()

func _on_time_expired(minigame: Node) -> void:
	if minigame != self:
		return
	finish_game(false)

func _update_timer_label() -> void:
	var mins = floor(current_time / 60)
	var secs = int(current_time) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]

func _register_gamepad_scheme() -> void:
	if MinigameController == null:
		return
	MinigameController.set_gamepad_scheme(self, {
		"mode": "focus",
		"focus_nodes": [generate_button],
		"enable_highlighter": false,
		"on_confirm": Callable(self, "_on_gamepad_confirm"),
		"hints": {
			"confirm": "Сгенерировать",
			"cancel": "Выход"
		}
	})

func _on_gamepad_confirm(active: Node, _context: Dictionary) -> bool:
	if active != generate_button:
		return false
	_on_generate_pressed()
	return true
