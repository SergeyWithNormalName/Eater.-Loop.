extends StaticBody2D

const INTERACTION_SCRIPT := preload("res://scripts/objects/interactive_object.gd")

enum ClearMode { HOLD, PRESS }

@export_group("Препятствие")
## Режим взаимодействия.
@export_enum("Удерживать", "Нажимать несколько раз") var clear_mode: int = ClearMode.HOLD
## Сколько секунд нужно удерживать кнопку.
@export var hold_time: float = 2.0
## Сколько нажатий нужно сделать.
@export var press_count: int = 5
## Сбрасывать прогресс при выходе из зоны.
@export var reset_on_exit: bool = true
## Текст подсказки при удержании.
@export var prompt_hold_text: String = "Удерживайте E, чтобы убрать препятствие"
## Текст подсказки при нажатиях.
@export var prompt_press_text: String = "Нажимайте E, чтобы убрать препятствие"
## Показывать прогресс в подсказке.
@export var show_progress_in_prompt: bool = true
## Сообщение после очистки (пусто = не показывать).
@export var cleared_message: String = ""

@onready var _interact_area: Area2D = $InteractArea
var _player_in_range: Node = null
var _hold_time: float = 0.0
var _presses: int = 0
var _last_prompt_text: String = ""

func _ready() -> void:
	if _interact_area:
		_ensure_interact_area_script()
		if _interact_area.has_signal("player_entered"):
			_interact_area.player_entered.connect(_on_interact_area_player_entered)
		if _interact_area.has_signal("player_exited"):
			_interact_area.player_exited.connect(_on_interact_area_player_exited)
	set_process(true)

func _process(delta: float) -> void:
	if _player_in_range == null:
		return
	if clear_mode != ClearMode.HOLD:
		return

	if Input.is_action_pressed("interact"):
		_hold_time += delta
		if hold_time <= 0.0 or _hold_time >= hold_time:
			_clear_obstacle()
			return
	else:
		if _hold_time > 0.0:
			_hold_time = 0.0

	_refresh_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null:
		return
	if clear_mode != ClearMode.PRESS:
		return
	if event.is_action_pressed("interact"):
		_presses += 1
		if _presses >= max(1, press_count):
			_clear_obstacle()
			return
		_refresh_prompt()

func _ensure_interact_area_script() -> void:
	if _interact_area.get_script() == INTERACTION_SCRIPT:
		_interact_area.auto_prompt = false
		_interact_area.handle_input = false
		return
	_interact_area.set_script(INTERACTION_SCRIPT)
	_interact_area.auto_prompt = false
	_interact_area.handle_input = false

func _on_interact_area_player_entered(player: Node) -> void:
	_player_in_range = player
	_refresh_prompt()

func _on_interact_area_player_exited(player: Node) -> void:
	if player == _player_in_range:
		_player_in_range = null
		if reset_on_exit:
			_reset_progress()
		_hide_prompt()

func _reset_progress() -> void:
	_hold_time = 0.0
	_presses = 0

func _build_prompt_text() -> String:
	if clear_mode == ClearMode.HOLD:
		var text: String = prompt_hold_text
		if show_progress_in_prompt:
			var duration: float = maxf(0.01, hold_time)
			var progress: float = clampf(_hold_time / duration, 0.0, 1.0)
			text = "%s (%d%%)" % [text, int(round(progress * 100.0))]
		return text

	var text_press: String = prompt_press_text
	if show_progress_in_prompt:
		var required: int = maxi(1, press_count)
		text_press = "%s (%d/%d)" % [text_press, _presses, required]
	return text_press

func _refresh_prompt() -> void:
	if InteractionPrompts == null:
		return
	var text: String = _build_prompt_text()
	if text == _last_prompt_text:
		return
	_last_prompt_text = text
	InteractionPrompts.show_interact(self, text)

func _hide_prompt() -> void:
	if InteractionPrompts:
		InteractionPrompts.hide_interact(self)
	_last_prompt_text = ""

func _clear_obstacle() -> void:
	_hide_prompt()
	if cleared_message.strip_edges() != "":
		UIMessage.show_text(cleared_message)
	queue_free()
