extends InteractiveObject
class_name Fridge

const InteractableAvailabilityVisualScript = preload("res://objects/interactable/shared/interactable_availability_visual.gd")
const CodeLockGateScript = preload("res://objects/interactable/shared/code_lock_gate.gd")
const IdleRocking2DScript = preload("res://objects/interactable/shared/idle_rocking_2d.gd")

signal feeding_finished

@export_group("Minigame (Feeding)")
## Сцена мини-игры (еда).
@export var minigame_scene: PackedScene
## Набор сцен еды.
@export var food_scenes: Array[PackedScene] = []
## Текстура лица Андрея.
@export var andrey_face: Texture2D
## Количество еды.
@export var food_count: int = 5
## Музыка и звуки.
@export var bg_music: AudioStream
@export var win_sound: AudioStream
@export var eat_sound: AudioStream
@export var background_texture: Texture2D

@export_group("Minigame (Unique Intro)")
## Уникальная версия feeding, которая запускается один раз за ран.
@export var unique_intro_minigame_scene: PackedScene = preload("res://levels/minigames/feeding/feed_minigame_detach_hands.tscn")
## Если включено, уникальный интро-этап будет только один раз за ран.
@export var unique_intro_once_per_run: bool = true

@export_group("Security")
## Требовать ввод кода доступа.
@export var require_access_code: bool = false
## Код доступа.
@export var access_code: String = "1234"
## Сообщение, если код не введен или неверный.
@export var access_code_failed_message: String = ""
## Сцена мини-игры "Кодовый замок".
@export var code_lock_scene: PackedScene

@export_group("Lab Requirement")
## Запретить еду, пока не сдана лабораторная.
@export var require_lab_completion: bool = false
## Если список не пуст, холодильник разблокируется только после выполнения всех указанных лабораторных в текущем цикле.
var _required_lab_completion_ids: PackedStringArray = PackedStringArray()
@export var required_lab_completion_ids: PackedStringArray:
	get:
		return _required_lab_completion_ids
	set(value):
		_required_lab_completion_ids = value
		if not _required_lab_completion_ids.is_empty():
			require_lab_completion = true
## Сообщение, если лабораторная еще не выполнена.
@export var lab_required_message: String = "Сначала нужно сделать лабораторную работу."

@export_group("Teleport")
@export var enable_teleport: bool = false
@export var teleport_target: NodePath

@export_group("Visuals & Audio")
@export var open_sound: AudioStream
## Фоновый шум холодильника.
@export var noise_sound: AudioStream
## Громкость шума холодильника (dB).
@export var noise_volume_db: float = -18.0
## Показывать заблокированный визуал после того, как игрок уже поел в этом цикле.
@export var use_locked_visual_after_eating: bool = false
## Узел проигрывателя шума.
@export var noise_player_node: NodePath = NodePath("AudioStreamPlayer2D")
@export var locked_sprite: Texture2D
@export var available_sprite: Texture2D
@export var sprite_node: NodePath = NodePath("Sprite2D")
@export var available_light_node: NodePath
@export var available_light_node_secondary: NodePath

@export_group("Idle Rocking")
## Длительность одного полного цикла (сек). Меньше = быстрее.
@export var rocking_cycle_duration: float = 2.0
## Сила покачивания в градусах.
@export var rocking_strength_degrees: float = 0.0
## Точка подвеса: 0 = по центру (обычные холодильники), 1 = подвес сверху.
@export_enum("Centered", "Hanging") var rocking_pivot_mode: int = 0
## Доп. смещение точки подвеса (пиксели, до масштаба).
@export var rocking_pivot_offset: Vector2 = Vector2.ZERO
## Звук покачивания.
@export var rocking_sound: AudioStream

var _is_interacting: bool = false
var _current_minigame: Node = null
var _sfx_player: AudioStreamPlayer = null
var _sprite: Sprite2D = null
var _available_light: CanvasItem = null
var _available_light_secondary: CanvasItem = null
var _noise_player: AudioStreamPlayer2D = null
var _availability_visual = InteractableAvailabilityVisualScript.new()
var _code_lock_gate = CodeLockGateScript.new()
var _rocking_controller = null

func _ready() -> void:
	super._ready()
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Sounds"
	add_child(_sfx_player)
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	_available_light = get_node_or_null(available_light_node) as CanvasItem
	_available_light_secondary = get_node_or_null(available_light_node_secondary) as CanvasItem
	_noise_player = get_node_or_null(noise_player_node) as AudioStreamPlayer2D
	if _noise_player != null:
		if noise_sound != null:
			_noise_player.stream = noise_sound
		_noise_player.volume_db = noise_volume_db
	_availability_visual.configure(
		_sprite,
		locked_sprite,
		available_sprite,
		[_available_light, _available_light_secondary],
		_noise_player
	)
	_code_lock_gate.configure(
		require_access_code,
		access_code,
		access_code_failed_message,
		code_lock_scene
	)
	_rocking_controller = IdleRocking2DScript.new()
	add_child(_rocking_controller)
	_rocking_controller.configure(
		_sprite,
		rocking_cycle_duration,
		rocking_strength_degrees,
		rocking_pivot_mode,
		rocking_pivot_offset,
		rocking_sound
	)
	_update_visuals()
	_start_rocking_if_configured()
	if CycleState != null:
		if _requires_lab_gate() and not CycleState.lab_completed.is_connected(_update_visuals):
			CycleState.lab_completed.connect(_update_visuals)
		if _requires_lab_gate() and not CycleState.lab_completed_with_id.is_connected(_on_lab_completed_with_id):
			CycleState.lab_completed_with_id.connect(_on_lab_completed_with_id)
		if not CycleState.ate_this_cycle_changed.is_connected(_on_ate_this_cycle_changed):
			CycleState.ate_this_cycle_changed.connect(_on_ate_this_cycle_changed)
		if not CycleState.cycle_state_reset.is_connected(_update_visuals):
			CycleState.cycle_state_reset.connect(_update_visuals)

func _on_interact() -> void:
	if _is_interacting:
		return
	if _requires_lab_gate() and not _has_required_lab_completion():
		_show_locked_message()
		return
	if CycleState != null and CycleState.has_eaten_this_cycle():
		UIMessage.show_notification("Я уже поел.")
		return
	if _code_lock_gate.needs_unlock():
		_start_code_lock()
		return
	_start_feeding_process()

func _start_code_lock() -> void:
	_code_lock_gate.request_unlock(
		self,
		Callable(self, "_attach_code_lock"),
		Callable(self, "_on_unlock_success"),
		Callable(self, "_show_access_code_failed_message"),
		Callable(self, "_set_interacting_state")
	)

func _attach_code_lock(lock_instance: Node) -> void:
	_current_minigame = lock_instance
	lock_instance.tree_exited.connect(_on_code_lock_tree_exited, Object.CONNECT_ONE_SHOT)
	attach_minigame(lock_instance)

func _on_code_lock_tree_exited() -> void:
	_current_minigame = null

func _on_unlock_success() -> void:
	_current_minigame = null
	UIMessage.show_notification("Замок открыт.")
	refresh_interaction_state()

func _start_feeding_process() -> void:
	_is_interacting = true
	if open_sound != null:
		_sfx_player.stream = open_sound
		_sfx_player.play()
	var has_food := not food_scenes.is_empty()
	var selected_scene := _resolve_feeding_scene()
	if selected_scene == null or not has_food:
		push_warning("Frizzer: Нет сцены мини-игры или еды!")
		_finish_feeding_logic()
		return
	var game := selected_scene.instantiate()
	_current_minigame = game
	attach_minigame(game)
	_mark_unique_intro_as_played(selected_scene)
	if game.has_method("setup_game"):
		game.setup_game(andrey_face, food_count, bg_music, win_sound, eat_sound, background_texture, food_scenes)
	game.minigame_finished.connect(_on_feeding_finished)

func _resolve_feeding_scene() -> PackedScene:
	if _should_use_unique_intro_scene():
		return unique_intro_minigame_scene
	return minigame_scene

func _should_use_unique_intro_scene() -> bool:
	if unique_intro_minigame_scene == null:
		return false
	if not unique_intro_once_per_run:
		return false
	if GameState == null:
		return true
	return not bool(GameState.is_unique_feeding_intro_played())

func _mark_unique_intro_as_played(scene_used: PackedScene) -> void:
	if not _is_scene_match(scene_used, unique_intro_minigame_scene):
		return
	if GameState == null:
		return
	GameState.mark_unique_feeding_intro_played()

func _is_scene_match(scene_a: PackedScene, scene_b: PackedScene) -> bool:
	if scene_a == null or scene_b == null:
		return false
	if scene_a == scene_b:
		return true
	return scene_a.resource_path != "" and scene_a.resource_path == scene_b.resource_path

func _on_feeding_finished() -> void:
	if _current_minigame != null:
		_current_minigame.queue_free()
		_current_minigame = null
	_finish_feeding_logic()
	_is_interacting = false

func _finish_feeding_logic() -> void:
	if enable_teleport:
		_clear_chase_after_teleport_success()
	if CycleState != null:
		CycleState.mark_ate()
	UIMessage.show_notification("Вкуснятина")
	if CycleState != null:
		CycleState.mark_fridge_interacted()
	feeding_finished.emit()
	complete_interaction()
	_teleport_player_if_needed()
	var tree := get_tree() if is_inside_tree() else null
	if GameState != null and tree != null:
		GameState.capture_fridge_checkpoint(tree.current_scene)
	elif GameState != null:
		GameState.autosave_run()

func _clear_chase_after_teleport_success() -> void:
	var tree := get_tree()
	if tree != null:
		tree.call_group("enemies", "force_stop_chase")
	if MusicManager != null:
		MusicManager.clear_chase_music_sources(0.2)

func _show_locked_message() -> void:
	if _requires_lab_gate() and not _has_required_lab_completion():
		if UIMessage:
			UIMessage.show_notification(lab_required_message)
		else:
			print("LOCKED: " + lab_required_message)
		return
	super._show_locked_message()

func _show_access_code_failed_message() -> void:
	var message := access_code_failed_message.strip_edges()
	if message == "":
		return
	if UIMessage:
		UIMessage.show_notification(message)
	else:
		print("LOCKED: " + message)

func _is_available_for_player() -> bool:
	var is_unlocked: bool = not require_access_code or bool(_code_lock_gate.unlocked)
	if _should_show_unavailable_after_eating():
		is_unlocked = false
	if _requires_lab_gate() and not _has_required_lab_completion():
		is_unlocked = false
	if dependency_object != null and not dependency_object.is_completed:
		is_unlocked = false
	return is_unlocked

func _update_visuals() -> void:
	_availability_visual.apply(_is_available_for_player())
	_update_rocking_pivot()

func refresh_visual_state() -> void:
	refresh_interaction_state()

func _on_dependency_finished() -> void:
	super._on_dependency_finished()
	_update_visuals()

func _on_lab_completed_with_id(_completed_id: String) -> void:
	_update_visuals()

func _on_ate_this_cycle_changed(_is_ate: bool) -> void:
	_update_visuals()

func _on_interaction_state_refreshed() -> void:
	_update_visuals()

func _teleport_player_if_needed() -> void:
	if not enable_teleport or teleport_target.is_empty():
		return
	var marker := get_node_or_null(teleport_target)
	if marker == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		player.global_position = marker.global_position

func _has_required_lab_completion() -> bool:
	if CycleState == null:
		return false
	if not required_lab_completion_ids.is_empty():
		return bool(CycleState.has_completed_all_labs(required_lab_completion_ids))
	return bool(CycleState.has_completed_any_lab())

func _requires_lab_gate() -> bool:
	return require_lab_completion or not required_lab_completion_ids.is_empty()

func _should_show_unavailable_after_eating() -> bool:
	if not use_locked_visual_after_eating:
		return false
	if CycleState == null:
		return false
	return bool(CycleState.has_eaten_this_cycle())

func _update_rocking_pivot() -> void:
	if _rocking_controller != null:
		_rocking_controller.apply_pivot()

func _start_rocking_if_configured() -> void:
	if _rocking_controller != null:
		_rocking_controller.start_if_configured()

func _stop_rocking() -> void:
	if _rocking_controller != null:
		_rocking_controller.stop()

func apply_winch_release_state() -> void:
	_stop_rocking()
	rocking_strength_degrees = 0.0
	rocking_pivot_mode = 0
	if _rocking_controller != null:
		_rocking_controller.apply_winch_release_state()

func capture_checkpoint_state() -> Dictionary:
	var state := super.capture_checkpoint_state()
	state["code_unlocked"] = _code_lock_gate.unlocked
	state["is_interacting"] = _is_interacting
	return state

func apply_checkpoint_state(state: Dictionary) -> void:
	super.apply_checkpoint_state(state)
	_code_lock_gate.apply_state({"unlocked": bool(state.get("code_unlocked", _code_lock_gate.unlocked))})
	_is_interacting = bool(state.get("is_interacting", false))
	_update_visuals()

func _set_interacting_state(value: bool) -> void:
	_is_interacting = value
