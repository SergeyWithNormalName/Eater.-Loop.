extends Node2D

@export_group("Trigger")
## Путь к триггеру Area2D, который запускает эффект.
@export var trigger_path: NodePath
## Группа, которую считаем игроком для срабатывания.
@export var player_group: String = "player"
## Если включено — срабатывает только один раз.
@export var one_shot: bool = true

@export_group("Stretch")
## Включить растяжение коридора (стены/пол).
@export var stretch_enabled: bool = true
## Узел-родитель, который растягивается (обычно контейнер стен/пола).
@export var stretch_root_path: NodePath
## Начальный масштаб растяжения (относительно базового).
@export var stretch_start_scale: Vector2 = Vector2(0.08, 1.0)
## Конечный масштаб растяжения (относительно базового).
@export var stretch_end_scale: Vector2 = Vector2(2.2, 1.0)
## Длительность растяжения.
@export var stretch_duration: float = 2.8
## Задержка перед началом растяжения.
@export var stretch_delay: float = 0.0
## Длительность проявления (alpha) растягиваемого коридора.
@export var stretch_fade_duration: float = 0.9
## Тип кривой анимации растяжения.
@export var stretch_trans: Tween.TransitionType = Tween.TRANS_SINE
## Тип easing для растяжения.
@export var stretch_ease: Tween.EaseType = Tween.EASE_OUT
## Длительность лёгкого «успокоения» после овершота.
@export var stretch_settle_duration: float = 0.5
## Сила овершота при растяжении (0 — без овершота).
@export var stretch_settle_strength: float = 0.05

@export_group("Kitchen")
## Список кухонных объектов, которые уезжают и исчезают.
@export var kitchen_nodes: Array[NodePath] = []
## Смещение кухонных объектов (куда уезжают).
@export var kitchen_move: Vector2 = Vector2(2200, 0)
## Длительность уезда кухни.
@export var kitchen_duration: float = 0.7
## Задержка перед уездом кухни.
@export var kitchen_delay: float = 0.0
## Длительность затухания кухни.
@export var kitchen_fade_duration: float = 0.7
## Задержка перед затуханием кухни.
@export var kitchen_fade_delay: float = 0.0
## Множитель масштаба кухни при уезде.
@export var kitchen_scale_mult: Vector2 = Vector2.ONE
## Тип кривой анимации уезда кухни.
@export var kitchen_trans: Tween.TransitionType = Tween.TRANS_CUBIC
## Тип easing для уезда кухни.
@export var kitchen_ease: Tween.EaseType = Tween.EASE_IN

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
var _stretch_root: Node2D
var _new_corridor: Node2D
var _camera: Camera2D
var _kitchen_nodes: Array[Node2D] = []
var _kitchen_base: Dictionary = {}
var _stretch_base_scale: Vector2 = Vector2.ONE
var _stretch_base_modulate: Color = Color.WHITE
var _new_base_pos: Vector2 = Vector2.ZERO
var _new_base_scale: Vector2 = Vector2.ONE
var _new_base_modulate: Color = Color.WHITE
var _camera_base_zoom: Vector2 = Vector2.ONE
var _audio_stop_scheduled := false

func _ready() -> void:
	_stretch_root = get_node_or_null(stretch_root_path) as Node2D
	_new_corridor = get_node_or_null(new_corridor_path) as Node2D
	_camera = get_node_or_null(camera_path) as Camera2D
	_cache_kitchen_nodes()

	if _stretch_root != null:
		_stretch_base_scale = _stretch_root.scale
		if _stretch_root is CanvasItem:
			_stretch_base_modulate = _stretch_root.modulate
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
	if _stretch_root != null and stretch_enabled:
		_stretch_root.scale = _stretch_base_scale * stretch_start_scale
		if _stretch_root is CanvasItem:
			var mod := _stretch_base_modulate
			mod.a = 0.0
			_stretch_root.modulate = mod
	if _new_corridor != null:
		_new_corridor.position = _new_base_pos + new_corridor_offset
		_new_corridor.scale = _new_base_scale * new_corridor_start_scale
		if _new_corridor is CanvasItem:
			var mod := _new_base_modulate
			mod.a = 0.0
			_new_corridor.modulate = mod
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

func _on_trigger_body_entered(body: Node) -> void:
	if one_shot and _has_fired:
		return
	if player_group != "" and not body.is_in_group(player_group):
		return
	_has_fired = true
	_play_sequence()

func _play_sequence() -> void:
	_animate_stretch()
	_animate_kitchen()
	_animate_new_corridor()
	_animate_camera_squash()
	_schedule_audio_stop()

func _animate_stretch() -> void:
	if _stretch_root == null or not stretch_enabled:
		return
	var target_scale := _stretch_base_scale * stretch_end_scale
	if stretch_settle_strength > 0.0:
		var overshoot_scale := target_scale * (1.0 + stretch_settle_strength)
		var scale_tween := create_tween()
		scale_tween.tween_property(_stretch_root, "scale", overshoot_scale, stretch_duration * 0.7).set_delay(stretch_delay).set_trans(stretch_trans).set_ease(stretch_ease)
		scale_tween.tween_property(_stretch_root, "scale", target_scale, stretch_settle_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		var scale_tween := create_tween()
		scale_tween.tween_property(_stretch_root, "scale", target_scale, stretch_duration).set_delay(stretch_delay).set_trans(stretch_trans).set_ease(stretch_ease)
	if _stretch_root is CanvasItem:
		var fade_tween := create_tween()
		fade_tween.tween_property(_stretch_root, "modulate:a", 1.0, stretch_fade_duration).set_delay(stretch_delay).set_trans(stretch_trans).set_ease(stretch_ease)

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
		if node is CanvasItem:
			tween.tween_property(node, "modulate:a", 0.0, kitchen_fade_duration).set_delay(kitchen_delay + kitchen_fade_delay).set_trans(kitchen_trans).set_ease(kitchen_ease)

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
	timer.timeout.connect(func(): _stop_audio_targets(targets))

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
