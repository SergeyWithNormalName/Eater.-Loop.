extends Area2D

@export var next_level_scene: PackedScene

@export_multiline var not_ate_message: String = "Нельзя спать: сначала поешь."
@export_multiline var sleep_message_template: String = "Поспал. Цикл %d → %d"

var _player_in_range: Node = null
var _is_sleeping: bool = false # Защита от повторного нажатия

func _ready() -> void:
	input_pickable = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body

func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null

func _unhandled_input(event: InputEvent) -> void:
	if _is_sleeping: return

	if event.is_action_pressed("interact") and _player_in_range != null:
		_try_sleep()

func _try_sleep() -> void:
	if not GameState.ate_this_cycle:
		UIMessage.show_text(not_ate_message)
		return

	_is_sleeping = true

	var old_cycle := GameState.cycle
	GameState.next_cycle()
	var new_cycle := GameState.cycle

	UIMessage.show_text(sleep_message_template % [old_cycle, new_cycle])
	
	# Даем игроку секунду прочитать сообщение перед тем, как экран погаснет
	await get_tree().create_timer(1.0).timeout

	if next_level_scene == null:
		push_warning("Bed: не назначена следующая сцена")
		_is_sleeping = false
		return

	# Плавная смена сцены
	await UIMessage.change_scene_with_fade(next_level_scene)
	
