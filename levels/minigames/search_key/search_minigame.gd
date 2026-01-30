extends Control

@export var trash_scene: PackedScene = preload("res://levels/minigames/ui/draggable_trash.tscn")
@export var key_texture: Texture2D
@export var trash_textures: Array[Texture2D] = []
@export var trash_count_range: Vector2i = Vector2i(5, 10)
@export var key_id: String = ""

var has_key: bool = false

@onready var search_area: Control = $SearchArea
@onready var key_button: TextureButton = $SearchArea/KeyButton
@onready var trash_container: Control = $SearchArea/TrashContainer

var _rng := RandomNumberGenerator.new()
var _setup_done: bool = false
var _layout_state: Dictionary = {}

func _ready() -> void:
	add_to_group("minigame_ui")
	add_to_group("search_key_minigame")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()

	key_button.visible = false
	key_button.focus_mode = Control.FOCUS_NONE
	key_button.mouse_filter = Control.MOUSE_FILTER_STOP
	key_button.pressed.connect(_on_key_pressed)
	_apply_key_texture()

	if not _setup_done:
		call_deferred("_spawn_content")

func setup(config: Dictionary) -> void:
	if config.has("has_key"):
		has_key = bool(config.get("has_key"))
	if config.has("key_id"):
		key_id = String(config.get("key_id"))
	if config.has("trash_range"):
		trash_count_range = config.get("trash_range")
	if config.has("trash_textures"):
		trash_textures = config.get("trash_textures")
	if config.has("key_texture"):
		key_texture = config.get("key_texture")
	if config.has("layout_state"):
		var state = config.get("layout_state")
		if state is Dictionary and not state.is_empty():
			_layout_state = state.duplicate(true)
		else:
			_layout_state = {}
	_setup_done = true
	call_deferred("_spawn_content")

func _spawn_content() -> void:
	await get_tree().process_frame
	_apply_key_texture()
	_clear_trash()

	var area_size := search_area.size
	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	key_button.visible = has_key
	if has_key:
		if _layout_state.has("key_pos"):
			key_button.position = _coerce_position(_layout_state.get("key_pos"))
		else:
			_place_control_randomly(key_button, area_size)

	if _layout_state.has("trash_items"):
		_spawn_trash_from_state(_layout_state.get("trash_items"))
	else:
		_spawn_trash(area_size)

func _apply_key_texture() -> void:
	if key_texture:
		key_button.texture_normal = key_texture

func _clear_trash() -> void:
	for child in trash_container.get_children():
		child.queue_free()

func _spawn_trash(area_size: Vector2) -> void:
	if trash_scene == null:
		return
	var min_count: int = mini(trash_count_range.x, trash_count_range.y)
	var max_count: int = maxi(trash_count_range.x, trash_count_range.y)
	var count := _rng.randi_range(min_count, max_count)

	for i in range(count):
		var trash = trash_scene.instantiate()
		trash_container.add_child(trash)
		if trash is TextureRect and not trash_textures.is_empty():
			trash.texture = trash_textures.pick_random()

		var trash_size := _get_control_size(trash as Control, Vector2(64, 64))
		trash.position = _random_position(area_size, trash_size)
		if trash is CanvasItem:
			trash.rotation_degrees = _rng.randf_range(0.0, 360.0)

func _spawn_trash_from_state(items: Variant) -> void:
	if trash_scene == null:
		return
	if not items is Array:
		return
	for item in items:
		if not item is Dictionary:
			continue
		var trash = trash_scene.instantiate()
		trash_container.add_child(trash)
		if trash is TextureRect:
			var texture := _resolve_trash_texture(item)
			if texture:
				trash.texture = texture
		var pos = item.get("pos", Vector2.ZERO)
		trash.position = _coerce_position(pos)
		if trash is CanvasItem and item.has("rot"):
			trash.rotation_degrees = float(item.get("rot"))

func _place_control_randomly(control: Control, area_size: Vector2) -> void:
	var control_size := _get_control_size(control, Vector2(64, 64))
	control.position = _random_position(area_size, control_size)

func _random_position(area_size: Vector2, item_size: Vector2) -> Vector2:
	var max_x: float = maxf(0.0, area_size.x - item_size.x)
	var max_y: float = maxf(0.0, area_size.y - item_size.y)
	return Vector2(_rng.randf_range(0.0, max_x), _rng.randf_range(0.0, max_y))

func _coerce_position(pos: Variant) -> Vector2:
	return pos if pos is Vector2 else Vector2.ZERO

func _get_control_size(control: Control, fallback: Vector2) -> Vector2:
	if control == null:
		return fallback
	var size := control.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = control.get_combined_minimum_size()
	if size.x <= 0.0 or size.y <= 0.0:
		size = fallback
	return size

func _resolve_trash_texture(item: Dictionary) -> Texture2D:
	if item.has("texture_index"):
		var idx := int(item.get("texture_index"))
		if idx >= 0 and idx < trash_textures.size():
			return trash_textures[idx]
	if item.has("texture_path"):
		var path := String(item.get("texture_path"))
		if path != "":
			var loaded = load(path)
			if loaded is Texture2D:
				return loaded
	if not trash_textures.is_empty():
		return trash_textures.pick_random()
	return null

func get_layout_state() -> Dictionary:
	var state: Dictionary = {}
	if has_key:
		state["key_pos"] = key_button.position
	var items: Array = []
	for child in trash_container.get_children():
		if not child is Control:
			continue
		var entry: Dictionary = {}
		entry["pos"] = (child as Control).position
		if child is CanvasItem:
			entry["rot"] = (child as CanvasItem).rotation_degrees
		if child is TextureRect:
			var tex := (child as TextureRect).texture
			if tex:
				var idx := trash_textures.find(tex)
				if idx != -1:
					entry["texture_index"] = idx
				if tex.resource_path != "":
					entry["texture_path"] = tex.resource_path
		items.append(entry)
	state["trash_items"] = items
	return state

func _on_key_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_key"):
		player.add_key(key_id)
	if UIMessage:
		UIMessage.show_text("Найден ключ!")
	_close_minigame(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mg_cancel"):
		_close_minigame(false)
		get_viewport().set_input_as_handled()

func on_minigame_cancel() -> void:
	_close_minigame(false)

func _close_minigame(success: bool) -> void:
	if MinigameController:
		MinigameController.finish_minigame(self, success)
	queue_free()

func _exit_tree() -> void:
	if MinigameController and MinigameController.is_active(self):
		MinigameController.finish_minigame(self, false)
