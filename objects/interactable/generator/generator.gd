extends "res://objects/interactable/interactive_object.gd"
## Звук включения электричества.
@export var power_on_sfx: AudioStream
## Громкость звука в дБ.
@export var power_on_volume_db: float = 0.0
## Сообщение, если электричество уже включено.
@export_multiline var already_on_message: String = ""

var _sfx_player: AudioStreamPlayer2D

func _ready() -> void:
	super._ready()
	input_pickable = false

	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.bus = "Sounds"
	_sfx_player.volume_db = power_on_volume_db
	add_child(_sfx_player)

func _on_interact() -> void:
	_activate()

func _activate() -> void:
	if GameState != null and GameState.electricity_on:
		if already_on_message != "":
			UIMessage.show_text(already_on_message)
		_play_sound()
		return

	if GameState != null:
		GameState.electricity_on = true
	_play_sound()

func _play_sound() -> void:
	if power_on_sfx == null:
		return
	_sfx_player.stream = power_on_sfx
	_sfx_player.volume_db = power_on_volume_db
	_sfx_player.pitch_scale = 1.0
	_sfx_player.play()
