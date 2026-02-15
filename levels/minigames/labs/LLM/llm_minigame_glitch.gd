extends Control

signal task_completed(success: bool)

@export_group("Game Logic")
@export var time_limit: float = 60.0
@export var penalty_time: float = 15.0
@export var progress_per_click: float = 0.1
@export var passive_progress_decay_per_second: float = 0.18

@export_group("Cooldowns")
@export_range(0.0, 5.0) var click_cooldown_min: float = 0.7
@export_range(0.0, 5.0) var click_cooldown_max: float = 1.6

var current_time: float = 0.0
var _progress: float = 0.0
var _is_finished: bool = false
var _cooldown_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()
var _button_target_position: Vector2 = Vector2.ZERO
var _next_jump_in: float = 0.0
var _fake_success_flash: float = 0.0

const LAB_MUSIC_STREAM := preload("res://music/TimerForLabs_DEMO.wav")

const TEXT_IDLE_VARIANTS := [
	"   Сгенерировать отчёт",
	"   Нажми, если сможешь",
	"   КНОПКА НЕ ЗДЕСЬ",
	"   [ERR:BUTTON_MOVED]",
	"   ПРОГРЕСС? ХА"
]
const TEXT_PROCESSING_VARIANTS := [
	"   Подождите...",
	"   думаю, но медленно",
	"   убегаю от курсора",
	"   компилирую отмазки",
	"   ÐŸÐ¾Ð´Ð¾Ð¶Ð´Ð¸Ñ‚Ðµ"
]
const TEXT_DONE = "   Отчёт готов! (невероятно)"

@onready var timer_label: Label = $GameTimerLabel
@onready var generate_button: Button = $CenterContainer/InteractionArea/InputButton
@onready var progress_bar: ProgressBar = $CenterContainer/InteractionArea/InputButton/ProgressBar
@onready var arrow_icon: Control = $CenterContainer/InteractionArea/InputButton/IconArrow
@onready var interaction_area: Control = $CenterContainer/InteractionArea

func _ready() -> void:
	add_to_group("minigame_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_minigame_session()

	current_time = time_limit
	_rng.randomize()

	_update_ui_state()
	_button_target_position = generate_button.position
	_schedule_next_jump()
	generate_button.pressed.connect(_on_generate_pressed)
	_register_gamepad_scheme()
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
			generate_button.text = "%s %.1fс" % [_pick(TEXT_PROCESSING_VARIANTS), _cooldown_remaining]

	_next_jump_in -= delta
	if _next_jump_in <= 0.0:
		_jump_button_to_chaos()

	# Если мышь близко к кнопке, она "пугается" и уезжает
	var mouse_pos := get_global_mouse_position()
	if generate_button.get_global_rect().grow(70.0).has_point(mouse_pos):
		if _rng.randf() < 0.24:
			_jump_button_to_chaos(true)

	generate_button.position = generate_button.position.lerp(_button_target_position, clamp(delta * 16.0, 0.0, 1.0))

	if _progress > 0.0:
		_progress = max(0.0, _progress - passive_progress_decay_per_second * delta)
		progress_bar.value = _progress * 100.0

	if _fake_success_flash > 0.0:
		_fake_success_flash -= delta
		if _fake_success_flash <= 0.0:
			progress_bar.modulate = Color.WHITE

func _on_generate_pressed() -> void:
	if _is_finished or _cooldown_remaining > 0.0:
		return

	var chaotic_gain := progress_per_click * _rng.randf_range(0.03, 0.18)
	if _rng.randf() < 0.22:
		chaotic_gain = -progress_per_click * _rng.randf_range(0.25, 0.6)

	_progress = clamp(_progress + chaotic_gain, 0.0, 0.96)

	# Иногда показывает фейковый "почти успех" и резко откатывает
	if _progress > 0.8 and _rng.randf() < 0.7:
		progress_bar.value = 100.0
		progress_bar.modulate = Color(0.5, 1.0, 0.5)
		_fake_success_flash = 0.2
		_progress = max(0.0, _progress - 0.45)

	var tween = create_tween()
	tween.tween_property(progress_bar, "value", _progress * 100.0, 0.08).set_trans(Tween.TRANS_SINE)

	if _progress >= 1.0:
		finish_game(true)
		return

	_start_click_cooldown()

func _start_click_cooldown() -> void:
	_cooldown_remaining = _rng.randf_range(click_cooldown_min, click_cooldown_max)
	generate_button.disabled = true
	generate_button.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62))
	if arrow_icon:
		arrow_icon.modulate = Color(0.3, 0.3, 0.3)

func _cooldown_finished() -> void:
	_cooldown_remaining = 0.0
	generate_button.disabled = false
	generate_button.text = _pick(TEXT_IDLE_VARIANTS)
	generate_button.remove_theme_color_override("font_color")
	if arrow_icon:
		arrow_icon.modulate = Color(1, 1, 1)

func _update_ui_state() -> void:
	progress_bar.value = _progress * 100.0
	generate_button.text = _pick(TEXT_IDLE_VARIANTS)

func _schedule_next_jump() -> void:
	_next_jump_in = _rng.randf_range(0.16, 0.52)

func _jump_button_to_chaos(from_mouse_escape: bool = false) -> void:
	if interaction_area == null:
		_schedule_next_jump()
		return
	var size := interaction_area.size
	var over := 220.0 if from_mouse_escape else 120.0
	_button_target_position = Vector2(
		_rng.randf_range(-over, size.x - generate_button.size.x + over),
		_rng.randf_range(-over, size.y - generate_button.size.y + over)
	)
	generate_button.text = _pick(TEXT_IDLE_VARIANTS)
	_schedule_next_jump()

func _pick(list: Array[String]) -> String:
	if list.is_empty():
		return ""
	return list[_rng.randi_range(0, list.size() - 1)]

func finish_game(success: bool) -> void:
	if _is_finished:
		return
	_is_finished = true
	if MinigameController:
		MinigameController.finish_minigame_with_fade(self, success, func():
			_finalize_finish(success)
		)
		return
	_finalize_finish(success)

func _finalize_finish(success: bool) -> void:
	if success:
		generate_button.text = TEXT_DONE
		var style = generate_button.get_theme_stylebox("normal").duplicate()
		style.border_color = Color.GREEN
		generate_button.add_theme_stylebox_override("normal", style)
	else:
		_shake_button()

	get_tree().create_timer(0.5).timeout.connect(func():
		task_completed.emit(success)

		if not success and get_tree().root.has_node("GameDirector"):
			get_tree().root.get_node("GameDirector").reduce_time(penalty_time)

		if success and get_tree().root.has_node("GameState"):
			var gs = get_tree().root.get_node("GameState")
			if gs and gs.has_method("mark_lab_completed"):
				gs.mark_lab_completed()

		queue_free()
	)

func _exit_tree() -> void:
	if MinigameController:
		MinigameController.clear_gamepad_scheme(self)
		if MinigameController.minigame_time_updated.is_connected(_on_time_updated):
			MinigameController.minigame_time_updated.disconnect(_on_time_updated)
		if MinigameController.minigame_time_expired.is_connected(_on_time_expired):
			MinigameController.minigame_time_expired.disconnect(_on_time_expired)
		if MinigameController.is_active(self):
			MinigameController.finish_minigame(self, false)

func _shake_button() -> void:
	var tween = create_tween()
	var orig_pos = generate_button.position.x
	for i in range(6):
		tween.tween_property(generate_button, "position:x", orig_pos + 6, 0.04)
		tween.tween_property(generate_button, "position:x", orig_pos - 6, 0.04)
	tween.tween_property(generate_button, "position:x", orig_pos, 0.04)

func _start_minigame_session() -> void:
	if MinigameController == null:
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

func _register_gamepad_scheme() -> void:
	if MinigameController == null:
		return
	MinigameController.set_gamepad_scheme(self, {
		"mode": "focus",
		"focus_nodes": [generate_button],
		"enable_highlighter": false,
		"on_confirm": Callable(self, "_on_gamepad_confirm"),
		"hints": {
			"confirm": "Попытка нажать",
			"cancel": "Выход"
		}
	})

func _on_gamepad_confirm(active: Node, _context: Dictionary) -> bool:
	if active != generate_button:
		return false
	_on_generate_pressed()
	return true
