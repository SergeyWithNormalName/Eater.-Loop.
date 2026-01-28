extends "res://objects/interactable/interactive_object.gd"

@export_category("Phone Settings")
## Звук звонка телефона.
@export var ring_sound: AudioStream
## Звук поднятия трубки.
@export var pickup_sound: AudioStream
## Интервал между звонками.
@export var ring_interval: float = 6.0

var _is_picked: bool = false
var _ring_timer: Timer
var _ring_player: AudioStreamPlayer
var _pickup_player: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	input_pickable = false
	
	_ring_player = AudioStreamPlayer.new()
	_ring_player.bus = "Sounds"
	_ring_player.stream = ring_sound
	add_child(_ring_player)

	_pickup_player = AudioStreamPlayer.new()
	_pickup_player.bus = "Sounds"
	_pickup_player.stream = pickup_sound
	add_child(_pickup_player)
	
	_ring_timer = Timer.new()
	_ring_timer.one_shot = true
	_ring_timer.timeout.connect(_on_ring_timer)
	add_child(_ring_timer)
	
	_start_ringing()

func _on_interact() -> void:
	if _is_picked:
		return
	_pickup()

func _start_ringing() -> void:
	if _is_picked:
		return
	if ring_sound:
		_ring_player.stream = ring_sound
	if ring_interval > 0.0:
		_ring_timer.start(ring_interval)
	else:
		_ring_timer.stop()

func _on_ring_timer() -> void:
	if _is_picked:
		return
	if _ring_player.stream:
		_ring_player.play()
	if ring_interval > 0.0:
		_ring_timer.start(ring_interval)

func _pickup() -> void:
	_is_picked = true
	_ring_timer.stop()
	_ring_player.stop()
	_hide_prompt()
	if pickup_sound:
		_pickup_player.stream = pickup_sound
	if _pickup_player.stream:
		_pickup_player.play()
	if GameState and GameState.has_method("mark_phone_picked"):
		GameState.mark_phone_picked()
