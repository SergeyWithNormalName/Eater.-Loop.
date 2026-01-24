extends Node2D

@export_group("Trigger")
## Путь к триггеру Area2D, который запускает эффект.
@export var trigger_path: NodePath
## Группа, которую считаем игроком для срабатывания.
@export var player_group: String = "player"
## Если включено — срабатывает только один раз.
@export var one_shot: bool = true

@export_group("Kitchen")
## Список кухонных объектов, которые уезжают.
@export var kitchen_nodes: Array[NodePath] = []
## Смещение кухонных объектов (куда уезжают).
@export var kitchen_move: Vector2 = Vector2(2200, 0)
## Длительность уезда кухни.
@export var kitchen_duration: float = 0.7
## Задержка перед уездом кухни.
@export var kitchen_delay: float = 0.0
## Множитель масштаба кухни при уезде.
@export var kitchen_scale_mult: Vector2 = Vector2.ONE
## Тип кривой анимации уезда кухни.
@export var kitchen_trans: Tween.TransitionType = Tween.TRANS_CUBIC
## Тип easing для уезда кухни.
@export var kitchen_ease: Tween.EaseType = Tween.EASE_IN

@export_group("Back Move")
## Список объектов коридора позади игрока, которые уезжают в обратную сторону.
@export var back_nodes: Array[NodePath] = []
## Смещение для объектов позади игрока.
@export var back_move: Vector2 = Vector2(-2200, 0)
## Длительность уезда объектов позади.
@export var back_duration: float = 0.7
## Задержка перед уездом объектов позади.
@export var back_delay: float = 0.0
## Тип кривой анимации уезда объектов позади.
@export var back_trans: Tween.TransitionType = Tween.TRANS_CUBIC
## Тип easing для уезда объектов позади.
@export var back_ease: Tween.EaseType = Tween.EASE_IN

@export_group("Disable Nodes")
## Узлы, которые скрываем и отключаем коллизии после триггера.
@export var disable_nodes: Array[NodePath] = []
## Задержка перед скрытием/отключением узлов.
@export var disable_delay: float = 0.0
## Скрывать CanvasItem узлы.
@export var disable_hide: bool = true
## Отключать коллизии у узлов.
@export var disable_collision: bool = true

@export_group("Audio Stop")
## Останавливать звуки у кухонных объектов, когда коридор уезжает.
@export var stop_kitchen_audio: bool = true
## Дополнительные узлы со звуком, которые нужно остановить (плееры или их родители).
@export var stop_audio_nodes: Array[NodePath] = []
## Задержка перед остановкой звука после триггера.
@export var stop_audio_delay: float = 2.0

@export_group("New Corridor")
## Узел-контейнер нового коридора, который проявляется.
@export var new_corridor_path: NodePath
## Стартовый оффсет нового коридора (откуда «въезжает»).
@export var new_corridor_offset: Vector2 = Vector2(650, 0)
## Начальный масштаб нового коридора.
@export var new_corridor_start_scale: Vector2 = Vector2(0.65, 0.9)
## Конечный масштаб нового коридора.
@export var new_corridor_end_scale: Vector2 = Vector2(1.0, 1.0)
## Длительность появления нового коридора.
@export var new_corridor_duration: float = 1.8
## Задержка перед появлением нового коридора.
@export var new_corridor_delay: float = 0.6
## Длительность проявления (alpha) нового коридора.
@export var new_corridor_fade_duration: float = 1.2
## Тип кривой анимации появления нового коридора.
@export var new_corridor_trans: Tween.TransitionType = Tween.TRANS_QUAD
## Тип easing для появления нового коридора.
@export var new_corridor_ease: Tween.EaseType = Tween.EASE_OUT

@export_group("Camera")
## Включить эффект сплющивания камеры.
@export var camera_enabled: bool = true
## Путь к Camera2D, которую будем «сплющивать».
@export var camera_path: NodePath
## Множитель зума по осям (меньше X и больше Y = сильнее сплющивание).
@export var camera_squash_zoom_mult: Vector2 = Vector2(0.75, 2.2)
## Длительность резкого сплющивания.
@export var camera_duration: float = 0.25
## Пауза удержания сплющенной камеры.
@export var camera_hold: float = 0.2
## Длительность возврата камеры в норму.
@export var camera_recover_duration: float = 0.8
## Задержка перед стартом сплющивания.
@export var camera_delay: float = 0.0
## Тип кривой анимации камеры.
@export var camera_trans: Tween.TransitionType = Tween.TRANS_SINE
## Тип easing для камеры.
@export var camera_ease: Tween.EaseType = Tween.EASE_OUT

var _has_fired := false
var _new_corridor: Node2D
var _camera: Camera2D
var _kitchen_nodes: Array[Node2D] = []
var _kitchen_base: Dictionary = {}
var _back_nodes: Array[Node2D] = []
var _back_base: Dictionary = {}
var _new_base_pos: Vector2 = Vector2.ZERO
var _new_base_scale: Vector2 = Vector2.ONE
var _new_base_modulate: Color = Color.WHITE
var _camera_base_zoom: Vector2 = Vector2.ONE
var _audio_stop_scheduled := false
var _disable_applied := false

func _ready() -> void:
	_new_corridor = get_node_or_null(new_corridor_path) as Node2D
	_camera = get_node_or_null(camera_path) as Camera2D
	_cache_kitchen_nodes()
	_cache_back_nodes()

	if _new_corridor != null:
		_new_base_pos = _new_corridor.position
		_new_base_scale = _new_corridor.scale
		if _new_corridor is CanvasItem:
			_new_base_modulate = _new_corridor.modulate
	if _camera != null:
		_camera_base_zoom = _camera.zoom

	_apply_initial_state()
	_connect_trigger()

func _connect_trigger() -> void:
	if trigger_path.is_empty():
		return
	var trigger := get_node_or_null(trigger_path)
	if trigger == null:
		return
	if trigger.has_signal("body_entered"):
		if not trigger.body_entered.is_connected(_on_trigger_body_entered):
			trigger.body_entered.connect(_on_trigger_body_entered)

func _apply_initial_state() -> void:
	if _new_corridor != null:
		_new_corridor.position = _new_base_pos + new_corridor_offset
		_new_corridor.scale = _new_base_scale * new_corridor_start_scale
		if _new_corridor is CanvasItem:
			var mod := _new_base_modulate
			mod.a = 0.0
			_new_corridor.modulate = mod
	for node in _back_nodes:
		var data: Dictionary = _back_base.get(node, {})
		if data.is_empty():
			continue
		node.global_position = data["global_position"]
		node.scale = data["scale"]
		if node is CanvasItem:
			node.modulate = data["modulate"]
	for node in _kitchen_nodes:
		var data: Dictionary = _kitchen_base.get(node, {})
		if data.is_empty():
			continue
		node.position = data["position"]
		node.scale = data["scale"]
		if node is CanvasItem:
			node.modulate = data["modulate"]

func _cache_kitchen_nodes() -> void:
	_kitchen_nodes.clear()
	_kitchen_base.clear()
	for path in kitchen_nodes:
		var node := get_node_or_null(path)
		if node == null:
			continue
		if node is Node2D:
			_kitchen_nodes.append(node)
			var mod := Color.WHITE
			if node is CanvasItem:
				mod = node.modulate
			_kitchen_base[node] = {
				"position": node.position,
				"scale": node.scale,
				"modulate": mod,
			}

func _cache_back_nodes() -> void:
	_back_nodes.clear()
	_back_base.clear()
	for path in back_nodes:
		var node := get_node_or_null(path)
		if node == null:
			continue
		if node is Node2D:
			_back_nodes.append(node)
			var mod := Color.WHITE
			if node is CanvasItem:
				mod = node.modulate
			_back_base[node] = {
				"global_position": node.global_position,
				"scale": node.scale,
				"modulate": mod,
			}

func _on_trigger_body_entered(body: Node) -> void:
	if one_shot and _has_fired:
		return
	if player_group != "" and not body.is_in_group(player_group):
		return
	_has_fired = true
	_play_sequence(body)

func _play_sequence(player_body: Node) -> void:
	_animate_kitchen()
	_animate_back_objects(player_body)
	_schedule_disable_nodes()
	_animate_new_corridor()
	_animate_camera_squash()
	_schedule_audio_stop()

func _animate_kitchen() -> void:
	if _kitchen_nodes.is_empty():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	for node in _kitchen_nodes:
		var data: Dictionary = _kitchen_base.get(node, {})
		if data.is_empty():
			continue
		var base_pos: Vector2 = data.get("position", Vector2.ZERO)
		var base_scale: Vector2 = data.get("scale", Vector2.ONE)
		var target_pos: Vector2 = base_pos + kitchen_move
		tween.tween_property(node, "position", target_pos, kitchen_duration).set_delay(kitchen_delay).set_trans(kitchen_trans).set_ease(kitchen_ease)
		if kitchen_scale_mult != Vector2.ONE:
			tween.tween_property(node, "scale", base_scale * kitchen_scale_mult, kitchen_duration).set_delay(kitchen_delay).set_trans(kitchen_trans).set_ease(kitchen_ease)

func _animate_back_objects(player_body: Node) -> void:
	if _back_nodes.is_empty():
		return
	var player_pos := Vector2.ZERO
	if player_body is Node2D:
		player_pos = player_body.global_position
	var tween := create_tween()
	tween.set_parallel(true)
	for node in _back_nodes:
		var data: Dictionary = _back_base.get(node, {})
		if data.is_empty():
			continue
		if node.global_position.x >= player_pos.x:
			continue
		var base_pos: Vector2 = data.get("global_position", node.global_position)
		var base_scale: Vector2 = data.get("scale", Vector2.ONE)
		var target_pos: Vector2 = base_pos + back_move
		tween.tween_property(node, "global_position", target_pos, back_duration).set_delay(back_delay).set_trans(back_trans).set_ease(back_ease)
		if node.scale != base_scale:
			tween.tween_property(node, "scale", base_scale, back_duration).set_delay(back_delay).set_trans(back_trans).set_ease(back_ease)

func _schedule_disable_nodes() -> void:
	if _disable_applied:
		return
	if disable_nodes.is_empty():
		return
	if disable_delay <= 0.0:
		_apply_disable_nodes()
		return
	var timer := get_tree().create_timer(disable_delay)
	timer.timeout.connect(_apply_disable_nodes)

func _apply_disable_nodes() -> void:
	if _disable_applied:
		return
	_disable_applied = true
	for path in disable_nodes:
		var node := get_node_or_null(path)
		if node == null:
			continue
		_disable_node_recursive(node)

func _disable_node_recursive(node: Node) -> void:
	if disable_hide and node is CanvasItem:
		node.set_deferred("visible", false)
	if disable_collision:
		if node is CollisionObject2D:
			node.set_deferred("collision_layer", 0)
			node.set_deferred("collision_mask", 0)
		if node is CollisionShape2D or node is CollisionPolygon2D:
			node.set_deferred("disabled", true)
	for child in node.get_children():
		_disable_node_recursive(child)

func _animate_new_corridor() -> void:
	if _new_corridor == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	var target_pos := _new_base_pos
	var start_pos := _new_base_pos + new_corridor_offset
	_new_corridor.position = start_pos
	var target_scale := _new_base_scale * new_corridor_end_scale
	_new_corridor.scale = _new_base_scale * new_corridor_start_scale
	tween.tween_property(_new_corridor, "position", target_pos, new_corridor_duration).set_delay(new_corridor_delay).set_trans(new_corridor_trans).set_ease(new_corridor_ease)
	tween.tween_property(_new_corridor, "scale", target_scale, new_corridor_duration).set_delay(new_corridor_delay).set_trans(new_corridor_trans).set_ease(new_corridor_ease)
	if _new_corridor is CanvasItem:
		tween.tween_property(_new_corridor, "modulate:a", 1.0, new_corridor_fade_duration).set_delay(new_corridor_delay).set_trans(new_corridor_trans).set_ease(new_corridor_ease)

func _animate_camera_squash() -> void:
	if _camera == null or not camera_enabled:
		return
	var target_zoom := Vector2(
		_camera_base_zoom.x * camera_squash_zoom_mult.x,
		_camera_base_zoom.y * camera_squash_zoom_mult.y
	)
	var tween := create_tween()
	tween.tween_property(_camera, "zoom", target_zoom, camera_duration).set_delay(camera_delay).set_trans(camera_trans).set_ease(camera_ease)
	if camera_hold > 0.0:
		tween.tween_interval(camera_hold)
	tween.tween_property(_camera, "zoom", _camera_base_zoom, camera_recover_duration).set_trans(camera_trans).set_ease(camera_ease)

func _schedule_audio_stop() -> void:
	if _audio_stop_scheduled:
		return
	var targets := _collect_audio_targets()
	if targets.is_empty():
		return
	_audio_stop_scheduled = true
	if stop_audio_delay <= 0.0:
		_stop_audio_targets(targets)
		return
	var timer := get_tree().create_timer(stop_audio_delay)
	timer.timeout.connect(_on_audio_stop_timeout.bind(targets))

func _on_audio_stop_timeout(targets: Array) -> void:
	_stop_audio_targets(targets)

func _collect_audio_targets() -> Array:
	var targets: Array = []
	for path in stop_audio_nodes:
		var node := get_node_or_null(path)
		if node != null:
			_append_audio_targets_from_node(node, targets)
	if stop_kitchen_audio:
		for node in _kitchen_nodes:
			_append_audio_targets_from_node(node, targets)
	return targets

func _append_audio_targets_from_node(node: Node, targets: Array) -> void:
	if node == null:
		return
	if _is_audio_node(node):
		if not targets.has(node):
			targets.append(node)
	for child in node.get_children():
		_append_audio_targets_from_node(child, targets)

func _is_audio_node(node: Node) -> bool:
	return node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D

func _stop_audio_targets(targets: Array) -> void:
	for node in targets:
		if not is_instance_valid(node):
			continue
		if node.has_method("stop"):
			node.call("stop")
