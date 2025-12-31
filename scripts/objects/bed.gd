extends Area2D

@export var level_by_cycle: Dictionary = {
	2: preload("res://scenes/cycles/level_02.tscn"),
	3: preload("res://scenes/cycles/level_03.tscn")
}

@export_multiline var not_ate_message: String = "Нельзя спать: сначала поешь."
@export_multiline var sleep_message_template: String = "Поспал. Цикл %d → %d"

var _player_in_range: Node = null

func _ready() -> void:
	input_pickable = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body

func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_in_range != null:
		_try_sleep()

func _try_sleep() -> void:
	if not GameState.ate_this_cycle:
		UIMessage.show_text(not_ate_message)
		return

	var old_cycle := GameState.cycle
	GameState.next_cycle()
	var new_cycle := GameState.cycle

	UIMessage.show_text(sleep_message_template % [old_cycle, new_cycle])

	var next_scene: PackedScene = level_by_cycle.get(new_cycle, null)
	if next_scene == null:
		push_warning("Bed: не назначена сцена для цикла " + str(new_cycle))
		# Можно добавить дефолтное действие или конец игры здесь
		return

	get_tree().change_scene_to_packed(next_scene)
