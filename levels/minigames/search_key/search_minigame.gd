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

func _ready() -> void:
	add_to_group("minigame_ui")
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
		_place_control_randomly(key_button, area_size)

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

func _place_control_randomly(control: Control, area_size: Vector2) -> void:
	var control_size := _get_control_size(control, Vector2(64, 64))
	control.position = _random_position(area_size, control_size)

func _random_position(area_size: Vector2, item_size: Vector2) -> Vector2:
	var max_x: float = maxf(0.0, area_size.x - item_size.x)
	var max_y: float = maxf(0.0, area_size.y - item_size.y)
	return Vector2(_rng.randf_range(0.0, max_x), _rng.randf_range(0.0, max_y))

func _get_control_size(control: Control, fallback: Vector2) -> Vector2:
	if control == null:
		return fallback
	var size := control.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = control.get_combined_minimum_size()
	if size.x <= 0.0 or size.y <= 0.0:
		size = fallback
	return size

func _on_key_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_key"):
		player.add_key(key_id)
	if UIMessage:
		UIMessage.show_text("Найден ключ!")
	_close_minigame(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mg_cancel") or event.is_action_pressed("ui_cancel"):
		_close_minigame(false)
		get_viewport().set_input_as_handled()

func _close_minigame(success: bool) -> void:
	if MinigameController:
		MinigameController.finish_minigame(self, success)
	queue_free()

func _exit_tree() -> void:
	if MinigameController and MinigameController.is_active(self):
		MinigameController.finish_minigame(self, false)
