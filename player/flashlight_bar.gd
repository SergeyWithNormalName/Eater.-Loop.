extends CanvasLayer

@export_group("Текстуры")
## Базовая подложка иконки фонарика (опционально).
## По умолчанию отключена, чтобы не дублировать белую заливку под индикатором.
@export var body_texture: Texture2D = null
## Заливка заряда, которая уменьшается сверху вниз.
@export var fill_texture: Texture2D = preload("res://player/ui/PouringFlashlight.png")
## Обводка фонарика (всегда видна поверх заливки).
@export var outline_texture: Texture2D = preload("res://player/ui/FlashlightDrawing.png")
## Лучики света, показываются при включенном фонарике и после полной зарядки.
@export var rays_texture: Texture2D = preload("res://player/ui/OnlySpotlight.png")

@export_group("Расположение")
## Масштаб иконки (от размера исходной текстуры).
@export_range(0.05, 1.0, 0.01) var icon_scale: float = 0.18
## Отступ от правого края экрана.
@export var right_offset: float = 28.0
## Отступ от нижнего края экрана.
@export var bottom_offset: float = 28.0

@export_group("Поведение")
## Скорость сглаживания изменения заряда (0 = без сглаживания).
@export var smoothing_speed: float = 16.0
## Длительность показа лучиков после полной зарядки.
@export var ready_show_time: float = 0.45

@export_group("Затухание")
## Задержка перед скрытием в состоянии покоя (сек).
@export var hide_delay: float = 0.2
## Длительность плавного скрытия (сек).
@export var fade_time: float = 0.2

var _icon_root: Control
var _body_rect: TextureRect
var _fill_clip: Control
var _fill_rect: TextureRect
var _outline_rect: TextureRect
var _rays_rect: TextureRect

var _ratio: float = 1.0
var _fade_alpha: float = 0.0
var _idle_time: float = 0.0
var _ready_time_left: float = 0.0
var _was_visible: bool = false
var _bound_player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_build_ui()
	_idle_time = hide_delay
	_fade_alpha = 0.0

func _process(delta: float) -> void:
	_update_visibility()
	if not visible:
		_idle_time = 0.0
		_fade_alpha = 0.0
		_ready_time_left = 0.0
		_apply_fade()
		return

	_bind_player_if_needed()
	_update_ratio(delta)
	_update_ready_timer(delta)
	_update_fade(delta)
	_apply_layout()
	_apply_fill_clip()
	_apply_rays_state()
	_apply_fade()

func _build_ui() -> void:
	_icon_root = Control.new()
	_icon_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_icon_root)

	if body_texture != null:
		_body_rect = _make_texture_rect(body_texture)
		_icon_root.add_child(_body_rect)

	_fill_clip = Control.new()
	_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_clip.clip_contents = true
	_fill_clip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_icon_root.add_child(_fill_clip)

	_fill_rect = _make_texture_rect(fill_texture)
	_fill_clip.add_child(_fill_rect)

	_outline_rect = _make_texture_rect(outline_texture)
	_icon_root.add_child(_outline_rect)

	_rays_rect = _make_texture_rect(rays_texture)
	_rays_rect.visible = false
	_icon_root.add_child(_rays_rect)

func _make_texture_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture = texture
	return rect

func _update_visibility() -> void:
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	var should_show := path.find("/levels/cycles/") != -1
	if should_show and not _was_visible:
		_idle_time = hide_delay
		_fade_alpha = 0.0
	visible = should_show
	_was_visible = should_show

func _bind_player_if_needed() -> void:
	var player := _get_player()
	if player == _bound_player:
		return

	var callback := Callable(self, "_on_player_flashlight_recharged")
	if _bound_player != null and _bound_player.has_signal(&"flashlight_recharged"):
		if _bound_player.is_connected(&"flashlight_recharged", callback):
			_bound_player.disconnect(&"flashlight_recharged", callback)

	_bound_player = player

	if _bound_player != null and _bound_player.has_signal(&"flashlight_recharged"):
		if not _bound_player.is_connected(&"flashlight_recharged", callback):
			_bound_player.connect(&"flashlight_recharged", callback)

func _update_ratio(delta: float) -> void:
	var player := _get_player()
	var target_ratio := 1.0
	if player != null and player.has_method("get_flashlight_charge_ratio"):
		target_ratio = float(player.get_flashlight_charge_ratio())
	target_ratio = clampf(target_ratio, 0.0, 1.0)
	if smoothing_speed <= 0.0:
		_ratio = target_ratio
		return
	var weight: float = clampf(delta * smoothing_speed, 0.0, 1.0)
	_ratio = lerpf(_ratio, target_ratio, weight)

func _update_ready_timer(delta: float) -> void:
	if _ready_time_left <= 0.0:
		return
	_ready_time_left = maxf(0.0, _ready_time_left - delta)

func _update_fade(delta: float) -> void:
	var player := _get_player()
	var flashlight_on := false
	if player != null and player.has_method("is_flashlight_enabled"):
		flashlight_on = bool(player.is_flashlight_enabled())

	var is_active := flashlight_on or _ready_time_left > 0.0
	var target_alpha := 1.0
	if is_active:
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

func _apply_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var icon_source_size := _get_source_texture_size()
	var scale_val := maxf(0.01, icon_scale)
	var icon_size := icon_source_size * scale_val
	var x_pos := maxf(0.0, viewport_size.x - icon_size.x - right_offset)
	var y_pos := maxf(0.0, viewport_size.y - icon_size.y - bottom_offset)

	_icon_root.position = Vector2(x_pos, y_pos)
	_icon_root.size = icon_size
	if _body_rect != null:
		_body_rect.position = Vector2.ZERO
		_body_rect.size = icon_size
	_outline_rect.position = Vector2.ZERO
	_outline_rect.size = icon_size
	_rays_rect.position = Vector2.ZERO
	_rays_rect.size = icon_size
	_fill_rect.size = icon_size

func _apply_fill_clip() -> void:
	var icon_size := _icon_root.size
	var ratio := clampf(_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		_fill_clip.visible = false
		return

	_fill_clip.visible = true
	var visible_height := icon_size.y * ratio
	var top_crop := icon_size.y - visible_height
	_fill_clip.position = Vector2(0.0, top_crop)
	_fill_clip.size = Vector2(icon_size.x, visible_height)
	_fill_rect.position = Vector2(0.0, -top_crop)

func _apply_rays_state() -> void:
	var player := _get_player()
	var flashlight_on := false
	if player != null and player.has_method("is_flashlight_enabled"):
		flashlight_on = bool(player.is_flashlight_enabled())
	_rays_rect.visible = flashlight_on or _ready_time_left > 0.0

func _apply_fade() -> void:
	_icon_root.modulate = Color(1.0, 1.0, 1.0, _fade_alpha)
	_icon_root.visible = _fade_alpha > 0.001

func _get_source_texture_size() -> Vector2:
	if fill_texture != null:
		return fill_texture.get_size()
	if outline_texture != null:
		return outline_texture.get_size()
	if rays_texture != null:
		return rays_texture.get_size()
	if body_texture != null:
		return body_texture.get_size()
	return Vector2(128.0, 128.0)

func _get_player() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	return player if player is Node else null

func _on_player_flashlight_recharged() -> void:
	_ready_time_left = maxf(0.0, ready_show_time)
	_idle_time = 0.0
	_fade_alpha = 1.0
	_ratio = 1.0
