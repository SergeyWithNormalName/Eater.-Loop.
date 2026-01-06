extends Area2D

@export_file("*.tscn") var next_level_path: String
@export var sleep_sfx: AudioStream

@export_multiline var not_ate_message: String = "Нельзя спать: сначала поешь."
@export_multiline var sleep_message_template: String = "Поспал. Цикл %d → %d"

var _player_in_range: Node = null
var _is_sleeping: bool = false # Защита от повторного нажатия
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	input_pickable = false
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	_sfx_player.stream = sleep_sfx
	if GameState.pending_sleep_spawn:
		GameState.pending_sleep_spawn = false
		if sleep_sfx != null:
			_sfx_player.play()

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
	if sleep_sfx != null:
		_sfx_player.stream = sleep_sfx
		_sfx_player.play()

	var old_cycle := GameState.cycle
	var new_cycle := GameState.cycle + 1

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
		GameState.next_cycle()
		GameState.emit_cycle_changed()
	)
