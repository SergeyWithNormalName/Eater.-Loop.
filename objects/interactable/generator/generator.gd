extends InteractiveObject

const PoweredSwitchableInteractableScript = preload("res://objects/interactable/powered_switchable_interactable.gd")

@export_group("Generator Settings")
## Список ламп, которые включатся.
@export var linked_lights: Array[Node] = []
## Активировать все лампы с флагом requires_generator в текущей сцене.
@export var activate_required_lamps_in_scene: bool = true

@export_group("Effects")
## Звук запуска (стартер).
@export var start_sfx: AudioStream
## Звук постоянной работы (гудение).
@export var loop_sfx: AudioStream
## Анимация включения (если есть AnimatedSprite2D).
@export var on_animation: String = "work"

@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _on_interact() -> void:
	if is_completed:
		if UIMessage:
			UIMessage.show_notification("Генератор работает стабильно.")
		return
	print("Генератор запускается...")
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(on_animation):
		sprite.play(on_animation)
	_start_audio()
	_activate_linked_lights()
	_activate_required_lamps_in_scene()
	if UIMessage:
		UIMessage.show_notification("Питание восстановлено!")
	complete_interaction()

func _on_start_sfx_finished() -> void:
	if loop_sfx != null and audio_player != null:
		audio_player.stream = loop_sfx
		audio_player.play()
	if audio_player != null and audio_player.finished.is_connected(_on_start_sfx_finished):
		audio_player.finished.disconnect(_on_start_sfx_finished)

func _activate_required_lamps_in_scene() -> void:
	if not activate_required_lamps_in_scene:
		return
	var tree := get_tree()
	if tree == null:
		return
	var activated: Dictionary = {}
	for light_node in tree.get_nodes_in_group("generator_required_light"):
		var powered = light_node
		if powered == null or not (powered is PoweredSwitchableInteractableScript):
			continue
		var node_id := powered.get_instance_id()
		if activated.has(node_id):
			continue
		activated[node_id] = true
		powered.set_powered(true)

func apply_checkpoint_state(state: Dictionary) -> void:
	super.apply_checkpoint_state(state)
	if not is_completed:
		return
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(on_animation):
		sprite.play(on_animation)
	_activate_linked_lights()
	_activate_required_lamps_in_scene()
	if audio_player != null:
		if loop_sfx != null:
			audio_player.stream = loop_sfx
			audio_player.play()
		elif start_sfx != null:
			audio_player.stream = start_sfx
			audio_player.play()

func _activate_linked_lights() -> void:
	for light_node in linked_lights:
		var light = light_node
		if light != null and light is PoweredSwitchableInteractableScript:
			light.set_powered(true)

func _start_audio() -> void:
	if audio_player == null:
		return
	if start_sfx != null:
		audio_player.stream = start_sfx
		audio_player.play()
		if not audio_player.finished.is_connected(_on_start_sfx_finished):
			audio_player.finished.connect(_on_start_sfx_finished)
		return
	if loop_sfx != null:
		audio_player.stream = loop_sfx
		audio_player.play()
