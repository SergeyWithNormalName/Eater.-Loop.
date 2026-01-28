extends InteractiveObject

@export_group("Generator Settings")
## Список ламп, которые включатся.
@export var linked_lights: Array[Node2D] = [] 

@export_group("Effects")
## Звук запуска (стартер).
@export var start_sfx: AudioStream
## Звук постоянной работы (гудение).
@export var loop_sfx: AudioStream
## Анимация включения (если есть AnimatedSprite2D).
@export var on_animation: String = "work"

# Ссылки на дочерние узлы (добавь их на сцену генератора!)
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _on_interact() -> void:
	# Если уже включен — просто пишем сообщение
	if is_completed:
		if UIMessage:
			UIMessage.show_message("Генератор работает стабильно.")
		return

	# --- ЛОГИКА ЗАПУСКА ---
	print("Генератор запускается...")
	
	# 1. Включаем анимацию (если есть спрайт и анимация)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(on_animation):
		sprite.play(on_animation)
	
	# 2. Включаем звук
	if audio_player:
		if start_sfx:
			# Сначала играем звук запуска
			audio_player.stream = start_sfx
			audio_player.play()
			# Подписываемся на окончание звука запуска, чтобы включить гудение
			if not audio_player.finished.is_connected(_on_start_sfx_finished):
				audio_player.finished.connect(_on_start_sfx_finished)
		elif loop_sfx:
			# Если звука запуска нет, сразу гудим
			audio_player.stream = loop_sfx
			audio_player.play()

	# 3. Включаем свет (можно добавить небольшую задержку через таймер для реализма)
	for light in linked_lights:
		if light and light.has_method("turn_on"):
			light.turn_on()
	
	if UIMessage:
		UIMessage.show_message("Питание восстановлено!")

	# 4. Фиксируем успех
	complete_interaction()

func _on_start_sfx_finished() -> void:
	# Когда звук "тыр-тыр-тыр" закончился, включаем "жжжжжж" (гудение)
	if loop_sfx and audio_player:
		audio_player.stream = loop_sfx
		audio_player.play()
		# Отключаем сигнал, чтобы не зациклилось странно
		if audio_player.finished.is_connected(_on_start_sfx_finished):
			audio_player.finished.disconnect(_on_start_sfx_finished)
			
			
