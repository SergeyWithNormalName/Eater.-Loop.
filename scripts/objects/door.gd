extends Area2D

# --- Настройки логики ---
@export var is_locked: bool = false
@export_multiline var locked_message: String = "Дверь закрыта."
@export var required_key_id: String = ""         
@export var required_key_name: String = ""       
@export var consume_key_on_unlock: bool = false

# --- Настройки перехода ---
@export var target_marker: NodePath
@export var target_scene: PackedScene
@export var use_scene_change: bool = false

# --- Настройки звука (НОВОЕ) ---
@export_group("Sounds")
@export var sfx_locked: AudioStream # Звук, когда дергаешь запертую дверь
@export var sfx_open: AudioStream   # Звук скрипа/открытия

var _player_in_range: Node = null
var _is_transitioning: bool = false 
var _audio_player: AudioStreamPlayer2D # Наш "динамик"

func _ready() -> void:
	input_pickable = false 
	
	# Создаем аудио-плеер программно
	_audio_player = AudioStreamPlayer2D.new()
	# Убираем затухание по дистанции, чтобы звук двери был четким, даже если камера чуть в стороне
	_audio_player.max_distance = 2000 
	add_child(_audio_player)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body

func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null

func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning: return
	
	if event.is_action_pressed("interact") and _player_in_range != null:
		_try_use_door()

func _try_use_door() -> void:
	if is_locked:
		if required_key_id != "":
			var player_has_key: bool = _player_in_range.has_method("has_key") and _player_in_range.has_key(required_key_id)
			
			if player_has_key:
				is_locked = false
				if consume_key_on_unlock and _player_in_range.has_method("remove_key"):
					_player_in_range.remove_key(required_key_id)
				
				UIMessage.show_text("Дверь открылась.")
				_play_sound(sfx_open) # ЗВУК: Открыли ключом
				_perform_transition()
				return
			else:
				if required_key_name != "":
					UIMessage.show_text("%s\nНужен: %s." % [locked_message, required_key_name])
				else:
					UIMessage.show_text(locked_message)
				
				_play_sound(sfx_locked) # ЗВУК: Дверь заперта
				return

		UIMessage.show_text(locked_message)
		_play_sound(sfx_locked) # ЗВУК: Дверь заперта (без ключа)
		return

	_play_sound(sfx_open) # ЗВУК: Обычное открытие
	_perform_transition()

func _perform_transition() -> void:
	_is_transitioning = true 
	
	var player = _player_in_range
	if not is_instance_valid(player):
		_is_transitioning = false
		return

	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	if use_scene_change:
		if target_scene == null:
			push_warning("Door: target_scene не задан.")
			if is_instance_valid(player): player.set_physics_process(true)
			_is_transitioning = false
			return
		
		# Звук успеет проиграться во время затемнения
		await UIMessage.change_scene_with_fade(target_scene)
		
	else:
		if target_marker.is_empty():
			push_warning("Door: target_marker не задан.")
			if is_instance_valid(player): player.set_physics_process(true)
			_is_transitioning = false
			return
			
		var marker := get_node_or_null(target_marker)
		if marker == null:
			push_warning("Door: target_marker не найден.")
			if is_instance_valid(player): player.set_physics_process(true)
			_is_transitioning = false
			return
		
		await UIMessage.fade_out(0.4)
		
		if is_instance_valid(player):
			player.global_position = marker.global_position
		
		await get_tree().create_timer(0.1).timeout
		await UIMessage.fade_in(0.4)
		
		if is_instance_valid(player) and player.has_method("set_physics_process"):
			player.set_physics_process(true)
		
		_is_transitioning = false

# Вспомогательная функция для проигрывания
func _play_sound(stream: AudioStream) -> void:
	if stream != null:
		_audio_player.stream = stream
		# Делаем питч чуть-чуть рандомным (от 0.9 до 1.1), 
		# чтобы звук не казался роботоподобным при частых нажатиях
		_audio_player.pitch_scale = randf_range(0.95, 1.05)
		_audio_player.play()
		
