extends Area2D

@export_category("Phone Settings")
## Звук звонка телефона.
@export var ring_sound: AudioStream
## Звук поднятия трубки.
@export var pickup_sound: AudioStream
## Интервал между звонками.
@export var ring_interval: float = 6.0

var _player_inside: bool = false
var _is_picked: bool = false
var _ring_timer: Timer
var _ring_player: AudioStreamPlayer
var _pickup_player: AudioStreamPlayer

func _ready() -> void:
	input_pickable = false
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
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

func _unhandled_input(event: InputEvent) -> void:
	if _is_picked or not _player_inside:
		return
	
	if event.is_action_pressed("interact"):
		_pickup()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if InteractionPrompts:
			InteractionPrompts.show_interact(self)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if InteractionPrompts:
			InteractionPrompts.hide_interact(self)

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
	if InteractionPrompts:
		InteractionPrompts.hide_interact(self)
	if pickup_sound:
		_pickup_player.stream = pickup_sound
	if _pickup_player.stream:
		_pickup_player.play()
	if GameState and GameState.has_method("mark_phone_picked"):
		GameState.mark_phone_picked()
