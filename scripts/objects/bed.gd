extends Area2D

## Путь к следующей сцене, куда переносить игрока после сна.
@export_file("*.tscn") var next_level_path: String
## Звук засыпания/пробуждения.
@export var sleep_sfx: AudioStream = preload("res://audio/furniture/OutOfBed.wav")

## Сообщение, если игрок не ел в этом цикле.
@export_multiline var not_ate_message: String = "Нельзя спать: сначала поешь."
## Шаблон сообщения после сна (старый/новый цикл).
@export_multiline var sleep_message_template: String = "Поспал. Цикл %d → %d"
## Требовать свет в спальне для сна.
@export var require_light_for_sleep: bool = false
## Сообщение, если света в спальне нет.
@export_multiline var no_bedroom_light_message: String = "Я боюсь засыпать в темноте..."

const DEFAULT_NO_LIGHT_MESSAGE: String = "Я боюсь засыпать в темноте..."

var _player_in_range: Node = null
var _is_sleeping: bool = false # Защита от повторного нажатия

func _ready() -> void:
	input_pickable = false
	if GameState.pending_sleep_spawn:
		GameState.pending_sleep_spawn = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body
		if InteractionPrompts:
			InteractionPrompts.show_interact(self)

func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null
		if InteractionPrompts:
			InteractionPrompts.hide_interact(self)

func _unhandled_input(event: InputEvent) -> void:
	if _is_sleeping: return

	if event.is_action_pressed("interact") and _player_in_range != null:
		_try_sleep()

func _try_sleep() -> void:
	if not GameState.ate_this_cycle:
		UIMessage.show_text(not_ate_message)
		return
	if require_light_for_sleep and not _is_bedroom_light_on():
		var message := no_bedroom_light_message
		if message == null or str(message).strip_edges() == "":
			message = DEFAULT_NO_LIGHT_MESSAGE
		UIMessage.show_text(str(message))
		return

	_is_sleeping = true

	var old_cycle := _get_current_cycle_number()
	if old_cycle <= 0:
		old_cycle = 1
	var new_cycle := _get_next_cycle_number(old_cycle + 1)

	if next_level_path.is_empty():
		push_warning("Bed: не назначена следующая сцена")
		_is_sleeping = false
		return
	UIMessage.show_text(sleep_message_template % [old_cycle, new_cycle])

	await UIMessage.fade_out(0.4)
	
	var next_level_scene := load(next_level_path) as PackedScene
	if next_level_scene == null:
		push_warning("Bed: не удалось загрузить следующую сцену: %s" % next_level_path)
		_is_sleeping = false
		await UIMessage.fade_in(0.4)
		return
	
	GameState.pending_sleep_spawn = true
	await UIMessage.change_scene_with_fade_delay(next_level_scene, 0.4, 1.0, func():
		if GameState.pending_sleep_spawn:
			GameState.pending_sleep_spawn = false
			if UIMessage and sleep_sfx != null:
				UIMessage.play_sfx(sleep_sfx)
		GameState.next_cycle()
	)

func _is_bedroom_light_on() -> bool:
	var lamps := get_tree().get_nodes_in_group("bedroom_lamp")
	for lamp in lamps:
		if lamp.has_method("is_light_active") and lamp.is_light_active():
			return true
	return false

func _get_current_cycle_number() -> int:
	var level := get_tree().current_scene
	if level != null and level.has_method("get_cycle_number"):
		return int(level.get_cycle_number())
	return 0

func _get_next_cycle_number(fallback: int) -> int:
	if next_level_path.is_empty():
		return fallback
	var scene := load(next_level_path) as PackedScene
	if scene == null:
		return fallback
	var instance := scene.instantiate()
	if instance == null:
		return fallback
	var cycle_number := fallback
	if instance.has_method("get_cycle_number"):
		cycle_number = int(instance.get_cycle_number())
	instance.free()
	if cycle_number <= 0:
		return fallback
	return cycle_number
