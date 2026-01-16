extends Node2D

## Cycle number for this level.
@export var cycle_number: int = 1
## Timer duration in seconds (0 = disabled).
@export var timer_duration: float = 0.0

@export_group("Стартовая подсказка")
## Показывать подсказку при входе на уровень.
@export var show_start_hint: bool = false
## Текст стартовой подсказки.
@export_multiline var start_hint_text: String = ""
## Картинка для подсказки (опционально).
@export var start_hint_texture: Texture2D
## Ставить игру на паузу при подсказке.
@export var pause_on_start_hint: bool = true

func _ready() -> void:
	if show_start_hint and start_hint_text.strip_edges() != "":
		call_deferred("_show_start_hint")

func get_cycle_number() -> int:
	return cycle_number

func get_timer_duration() -> float:
	return timer_duration

func _show_start_hint() -> void:
	if not show_start_hint:
		return
	var text := start_hint_text.strip_edges()
	if text == "":
		return
	var attempts := 0
	while attempts < 3:
		var viewport_size := get_viewport().get_visible_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			break
		await get_tree().process_frame
		attempts += 1
	UIMessage.show_hint(text, start_hint_texture, pause_on_start_hint)
