extends Area2D

@export_group("Trigger")
@export var affect_on_enter: bool = true
@export var affect_on_exit: bool = false
@export var one_shot: bool = true
@export var player_group: String = "player"

@export_group("Targets")
@export var changes: Array[PropertyChange] = []
@export var target_paths: Array[NodePath] = []
@export var property_name: String = ""
@export var value: Variant

@export_group("Sound")
@export var sfx_stream: AudioStream
@export var sfx_position: Vector2 = Vector2.ZERO
@export var sfx_use_trigger_position: bool = false
@export var sfx_delay: float = 0.0
@export var sfx_volume_db: float = 0.0

var _has_fired: bool = false

func _ready() -> void:
	input_pickable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not affect_on_enter:
		return
	if _has_fired and one_shot:
		return
	if not body.is_in_group(player_group):
		return
	_apply()

func _on_body_exited(body: Node) -> void:
	if not affect_on_exit:
		return
	if _has_fired and one_shot:
		return
	if not body.is_in_group(player_group):
		return
	_apply()

func _apply() -> void:
	if changes.size() > 0:
		for change in changes:
			_apply_change(change)
	else:
		if property_name == "":
			return
		for path in target_paths:
			var node := get_node_or_null(path)
			if node == null:
				continue
			if not _has_property(node, property_name):
				continue
			node.set(property_name, value)
	_play_sound()
	_has_fired = true

func _play_sound() -> void:
	if sfx_stream == null:
		return
	var play := func() -> void:
		var player := AudioStreamPlayer2D.new()
		player.stream = sfx_stream
		player.volume_db = sfx_volume_db
		player.global_position = global_position if sfx_use_trigger_position else sfx_position
		player.finished.connect(player.queue_free)
		get_tree().current_scene.add_child(player)
		player.play()
	if sfx_delay > 0.0:
		get_tree().create_timer(sfx_delay).timeout.connect(play)
	else:
		play.call()

func _apply_change(change: PropertyChange) -> void:
	if change == null:
		return
	var target_path: NodePath = change.target
	var prop: String = change.property_name
	var val: Variant = change.value
	if target_path.is_empty() or prop == "":
		return
	var node := get_node_or_null(target_path)
	if node == null:
		return
	if not _has_property(node, prop):
		return
	node.set(prop, val)

func _has_property(node: Node, prop: String) -> bool:
	for info in node.get_property_list():
		if info.name == prop:
			return true
	return false
