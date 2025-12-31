extends Area2D

@export var key_id: String = "bedroom_key"
@export var key_name: String = "Ключ"
@export_multiline var pickup_message: String = "Подобрал"

var _player_in_range: Node = null
var _picked: bool = false

func _ready() -> void:
	input_pickable = true

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body

func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_pickup()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_in_range != null:
		_try_pickup()

func _try_pickup() -> void:
	if _picked or _player_in_range == null:
		return

	_picked = true

	if _player_in_range.has_method("add_key"):
		_player_in_range.add_key(key_id)

	UIMessage.show_text("%s: %s" % [pickup_message, key_name])
	queue_free()
