extends CanvasLayer

@export_group("Шкала выносливости")
## Высота линии (в пикселях).
@export var bar_height: float = 2.0
## Цвет линии.
@export var bar_color: Color = Color(1, 1, 1, 1)
## Отступ от верхнего края (в пикселях).
@export var top_offset: float = 4.0
## Скорость сглаживания изменений (0 = без сглаживания).
@export var smoothing_speed: float = 12.0

@export_group("Затухание")
## Задержка перед скрытием, если игрок не бежит (сек).
@export var hide_delay: float = 2.0
## Длительность плавного скрытия (сек).
@export var fade_time: float = 0.4

var _bar: ColorRect
var _ratio: float = 1.0
var _fade_alpha: float = 0.0
var _idle_time: float = 0.0
var _was_visible: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95

	_bar = ColorRect.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_bar)
	_idle_time = hide_delay
	_fade_alpha = 0.0

func _process(delta: float) -> void:
	_update_visibility()
	if not visible:
		_idle_time = 0.0
		_fade_alpha = 0.0
		return
	_update_ratio(delta)
	_update_fade(delta)
	_apply_bar()

func _update_visibility() -> void:
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	var should_show := path.find("/levels/cycles/") != -1
	if should_show and not _was_visible:
		_idle_time = hide_delay
		_fade_alpha = 0.0
	visible = should_show
	_was_visible = should_show

func _update_ratio(delta: float) -> void:
	var player := _get_player()
	var target_ratio := 1.0
	if player != null and player.has_method("get_stamina_ratio"):
		target_ratio = float(player.get_stamina_ratio())
	target_ratio = clamp(target_ratio, 0.0, 1.0)
	if smoothing_speed <= 0.0:
		_ratio = target_ratio
		return
	var weight: float = clampf(delta * smoothing_speed, 0.0, 1.0)
	_ratio = lerp(_ratio, target_ratio, weight)

func _apply_bar() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var color := bar_color
	color.a *= _fade_alpha
	_bar.color = color
	_bar.position = Vector2(0.0, top_offset)
	_bar.size = Vector2(viewport_size.x * _ratio, max(1.0, bar_height))

func _get_player() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	return player if player is Node else null

func _update_fade(delta: float) -> void:
	var player := _get_player()
	var is_running := false
	if player != null and player.has_method("is_running"):
		is_running = bool(player.is_running())

	var target_alpha := 1.0
	if is_running:
		_idle_time = 0.0
	else:
		_idle_time += delta
		if _idle_time >= hide_delay:
			target_alpha = 0.0

	if fade_time <= 0.0:
		_fade_alpha = target_alpha
		return

	var step := delta / fade_time
	_fade_alpha = move_toward(_fade_alpha, target_alpha, step)
