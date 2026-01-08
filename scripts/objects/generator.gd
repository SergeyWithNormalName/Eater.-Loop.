extends Area2D

@export_group("Interaction")
@export var interact_area_node: NodePath = NodePath("")
@export var power_on_sfx: AudioStream
@export var power_on_volume_db: float = 0.0
@export_multiline var already_on_message: String = ""

var _player_inside: bool = false
var _interact_area: Area2D = null
var _sfx_player: AudioStreamPlayer2D

func _ready() -> void:
	input_pickable = false

	_interact_area = get_node_or_null(interact_area_node) as Area2D
	if _interact_area == null:
		_interact_area = self
	if _interact_area:
		if not _interact_area.body_entered.is_connected(_on_body_entered):
			_interact_area.body_entered.connect(_on_body_entered)
		if not _interact_area.body_exited.is_connected(_on_body_exited):
			_interact_area.body_exited.connect(_on_body_exited)

	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.volume_db = power_on_volume_db
	add_child(_sfx_player)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_pressed("interact"):
		_activate()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false

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
