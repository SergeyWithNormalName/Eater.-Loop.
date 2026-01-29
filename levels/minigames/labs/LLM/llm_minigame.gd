extends Control

# --- СИГНАЛЫ ---
signal task_completed(success: bool)

# --- НАСТРОЙКИ ---
@export_group("Game Logic")
## Лимит времени на мини-игру (сек).
@export var time_limit: float = 60.0
## Штраф по времени за провал (сек).
@export var penalty_time: float = 15.0
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

const LAB_MUSIC_STREAM := preload("res://music/TimerForLabs_DEMO.wav")

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
	_start_minigame_session()

	current_time = time_limit
	_rng.randomize()

	_update_ui_state()
	generate_button.pressed.connect(_on_generate_pressed)
	if MinigameController == null:
		_update_timer_label()

func _process(delta: float) -> void:
	if _is_finished:
		return

	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0.0:
			_cooldown_finished()
		else:
			generate_button.text = TEXT_PROCESSING + "%.1f сек" % _cooldown_remaining

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
	if MinigameController:
		MinigameController.finish_minigame(self, success)

	if success:
		generate_button.text = TEXT_DONE
		var style = generate_button.get_theme_stylebox("normal").duplicate()
		style.border_color = Color.GREEN
		generate_button.add_theme_stylebox_override("normal", style)
	else:
		_shake_button()

	await get_tree().create_timer(0.5).timeout

	task_completed.emit(success)

	if not success:
		if get_tree().root.has_node("GameDirector"):
			get_tree().root.get_node("GameDirector").reduce_time(penalty_time)

	if success and get_tree().root.has_node("GameState"):
		var gs = get_tree().root.get_node("GameState")
		if gs and gs.has_method("mark_lab_completed"):
			gs.mark_lab_completed()

	queue_free()

func _exit_tree() -> void:
	if MinigameController:
		if MinigameController.minigame_time_updated.is_connected(_on_time_updated):
			MinigameController.minigame_time_updated.disconnect(_on_time_updated)
		if MinigameController.minigame_time_expired.is_connected(_on_time_expired):
			MinigameController.minigame_time_expired.disconnect(_on_time_expired)
		if MinigameController.is_active(self):
			MinigameController.finish_minigame(self, false)

func _shake_button() -> void:
	var tween = create_tween()
	var orig_pos = generate_button.position.x
	for i in range(5):
		tween.tween_property(generate_button, "position:x", orig_pos + 5, 0.05)
		tween.tween_property(generate_button, "position:x", orig_pos - 5, 0.05)
	tween.tween_property(generate_button, "position:x", orig_pos, 0.05)

func _input(event: InputEvent) -> void:
	if _is_finished:
		return
	if event.is_action_pressed("mg_grab"):
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered == generate_button:
			_on_generate_pressed()

func _start_minigame_session() -> void:
	if MinigameController == null:
		return
	_ensure_lab_music_loop()
	if not MinigameController.is_active(self):
		MinigameController.start_minigame(self, {
			"pause_game": false,
			"enable_gamepad_cursor": true,
			"block_player_movement": true,
			"time_limit": time_limit,
			"music_stream": LAB_MUSIC_STREAM,
			"music_fade_time": 0.0,
			"auto_finish_on_timeout": false
		})
	current_time = time_limit
	_update_timer_label()
	if not MinigameController.minigame_time_updated.is_connected(_on_time_updated):
		MinigameController.minigame_time_updated.connect(_on_time_updated)
	if not MinigameController.minigame_time_expired.is_connected(_on_time_expired):
		MinigameController.minigame_time_expired.connect(_on_time_expired)

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
