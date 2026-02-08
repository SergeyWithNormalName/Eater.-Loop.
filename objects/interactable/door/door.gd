extends "res://objects/interactable/interactive_object.gd"

# --- Настройки логики ---
## Дверь закрыта и требует ключ или сообщение.
@export var is_locked: bool = false
## Сообщение, когда дверь заперта.
@export_multiline var door_locked_message: String = "Дверь закрыта."

# --- Настройки внешнего вида ---
## Текстура номера для дочернего Sprite2D "Number" (если есть).
@export var number_texture: Texture2D

# --- Настройки перехода ---
## Маркер, куда телепортировать игрока.
@export var target_marker: NodePath

# --- Настройки внешнего вида ---
@export_group("Key")
## ID ключа, который открывает дверь (пусто — не нужен).
@export var required_key_id: String = ""         
## Название ключа для текста подсказки.
@export var required_key_name: String = ""       
## Удалять ключ из инвентаря при открытии.
@export var consume_key_on_unlock: bool = false

@export_group("Visual")
## Текстура двери для Sprite2D.
@export var door_texture: Texture2D

# --- Настройки звука (НОВОЕ) ---
@export_group("Sounds")
## Звук, когда дергаешь запертую дверь.
@export var sfx_locked: AudioStream # Звук, когда дергаешь запертую дверь
## Звук скрипа/открытия.
@export var sfx_open: AudioStream   # Звук скрипа/открытия

var _is_transitioning: bool = false 
var _audio_player: AudioStreamPlayer2D # Наш "динамик"
var _sprite: Sprite2D
var _number_sprite: Sprite2D

func _ready() -> void:
	super._ready()
	if not is_in_group("doors"):
		add_to_group("doors")
	input_pickable = false 
	_sprite = get_node_or_null("Sprite2D")
	_number_sprite = get_node_or_null("Number")
	_apply_door_texture()
	_apply_number_texture()
	
	# Создаем аудио-плеер программно
	_audio_player = AudioStreamPlayer2D.new()
	_audio_player.bus = "Sounds"
	# Убираем затухание по дистанции, чтобы звук двери был четким, даже если камера чуть в стороне
	_audio_player.max_distance = 2000 
	add_child(_audio_player)

func _on_interact() -> void:
	if _is_transitioning:
		return
	_try_use_door()

func _try_use_door() -> void:
	var player = get_interacting_player()
	if player == null:
		return
	if is_locked:
		if required_key_id != "":
			var player_has_key: bool = player.has_method("has_key") and player.has_key(required_key_id)
			
			if player_has_key:
				is_locked = false
				if consume_key_on_unlock and player.has_method("remove_key"):
					player.remove_key(required_key_id)
				
				UIMessage.show_text("Дверь открылась.")
				_play_sound(sfx_open) # ЗВУК: Открыли ключом
				_perform_transition()
				return
			else:
				if required_key_name != "":
					UIMessage.show_text("%s\nНужен: %s." % [door_locked_message, required_key_name])
				else:
					UIMessage.show_text(door_locked_message)
				
				_play_sound(sfx_locked) # ЗВУК: Дверь заперта
				return

		UIMessage.show_text(door_locked_message)
		_play_sound(sfx_locked) # ЗВУК: Дверь заперта (без ключа)
		return

	_play_sound(sfx_open) # ЗВУК: Обычное открытие
	_perform_transition()

func _perform_transition() -> void:
	_is_transitioning = true 
	_stop_chase_for_transition()
	
	var player = get_interacting_player()
	if not is_instance_valid(player):
		_is_transitioning = false
		return

	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
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

func _stop_chase_for_transition() -> void:
	get_tree().call_group("enemies", "force_stop_chase")
	if MusicManager:
		MusicManager.clear_chase_music_sources(0.2)

func _apply_door_texture() -> void:
	if _sprite != null and door_texture != null:
		_sprite.texture = door_texture

func _apply_number_texture() -> void:
	if _number_sprite != null and number_texture != null:
		_number_sprite.texture = number_texture

# Вспомогательная функция для проигрывания
func _play_sound(stream: AudioStream) -> void:
	if stream != null:
		_audio_player.stream = stream
		# Делаем питч чуть-чуть рандомным (от 0.9 до 1.1), 
		# чтобы звук не казался роботоподобным при частых нажатиях
		_audio_player.pitch_scale = randf_range(0.95, 1.05)
		_audio_player.play()
		
