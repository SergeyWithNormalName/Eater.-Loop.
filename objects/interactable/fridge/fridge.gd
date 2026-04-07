extends InteractiveObject
class_name Fridge

const InteractableAvailabilityVisualScript = preload("res://objects/interactable/shared/interactable_availability_visual.gd")
const CodeLockGateScript = preload("res://objects/interactable/shared/code_lock_gate.gd")
const IdleRocking2DScript = preload("res://objects/interactable/shared/idle_rocking_2d.gd")
const FridgeUniqueIntroConfigScript = preload("res://objects/interactable/fridge/fridge_unique_intro_config.gd")
const FridgeCodeLockConfigScript = preload("res://objects/interactable/fridge/fridge_code_lock_config.gd")
const FridgeLabRequirementConfigScript = preload("res://objects/interactable/fridge/fridge_lab_requirement_config.gd")
const FridgeTeleportConfigScript = preload("res://objects/interactable/fridge/fridge_teleport_config.gd")
const IdleRockingConfigScript = preload("res://objects/interactable/shared/idle_rocking_config.gd")

const DEFAULT_LAB_REQUIRED_MESSAGE := "Сначала нужно сделать лабораторную работу."

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

@export_group("Optional Features")
@export var unique_intro_config: Resource
@export var code_lock_config: Resource
@export var lab_requirement_config: Resource
@export var teleport_config: Resource
@export var idle_rocking_config: Resource

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

var unique_intro_minigame_scene: PackedScene:
	get:
		return unique_intro_config.minigame_scene if unique_intro_config != null else null
	set(value):
		if value == null:
			unique_intro_config = null
			return
		_ensure_unique_intro_config().minigame_scene = value

var unique_intro_once_per_run: bool:
	get:
		return unique_intro_config != null and unique_intro_config.once_per_run
	set(value):
		if not value and unique_intro_config == null:
			return
		_ensure_unique_intro_config().once_per_run = value

var require_access_code: bool:
	get:
		return code_lock_config != null and code_lock_config.enabled
	set(value):
		if value:
			_ensure_code_lock_config().enabled = true
			return
		if code_lock_config == null:
			return
		code_lock_config.enabled = false
		_cleanup_code_lock_config()

var access_code: String:
	get:
		return code_lock_config.access_code if code_lock_config != null else "1234"
	set(value):
		_ensure_code_lock_config().access_code = value

var access_code_failed_message: String:
	get:
		return code_lock_config.access_code_failed_message if code_lock_config != null else ""
	set(value):
		_ensure_code_lock_config().access_code_failed_message = value

var code_lock_scene: PackedScene:
	get:
		return code_lock_config.code_lock_scene if code_lock_config != null else null
	set(value):
		if value == null:
			if code_lock_config != null:
				code_lock_config.code_lock_scene = null
			return
		_ensure_code_lock_config().code_lock_scene = value

var require_lab_completion: bool:
	get:
		return lab_requirement_config != null and (
			lab_requirement_config.require_any_lab_completion
			or not lab_requirement_config.required_lab_completion_ids.is_empty()
		)
	set(value):
		if value:
			_ensure_lab_requirement_config().require_any_lab_completion = true
			return
		if lab_requirement_config == null:
			return
		lab_requirement_config.require_any_lab_completion = false
		_cleanup_lab_requirement_config()

var required_lab_completion_ids: PackedStringArray:
	get:
		if lab_requirement_config == null:
			return PackedStringArray()
		return lab_requirement_config.required_lab_completion_ids
	set(value):
		if value.is_empty():
			if lab_requirement_config != null:
				lab_requirement_config.required_lab_completion_ids = value
				_cleanup_lab_requirement_config()
			return
		_ensure_lab_requirement_config().required_lab_completion_ids = value

var lab_required_message: String:
	get:
		if lab_requirement_config == null:
			return DEFAULT_LAB_REQUIRED_MESSAGE
		return lab_requirement_config.required_message
	set(value):
		if value == DEFAULT_LAB_REQUIRED_MESSAGE and lab_requirement_config == null:
			return
		_ensure_lab_requirement_config().required_message = value
		_cleanup_lab_requirement_config()

var enable_teleport: bool:
	get:
		return teleport_config != null
	set(value):
		if value:
			_ensure_teleport_config()
			return
		teleport_config = null

var teleport_target: NodePath:
	get:
		return teleport_config.target if teleport_config != null else NodePath()
	set(value):
		if value.is_empty():
			if teleport_config != null:
				teleport_config.target = value
				_cleanup_teleport_config()
			return
		_ensure_teleport_config().target = value

var rocking_cycle_duration: float:
	get:
		return idle_rocking_config.cycle_duration if idle_rocking_config != null else 2.0
	set(value):
		_ensure_idle_rocking_config().cycle_duration = value

var rocking_strength_degrees: float:
	get:
		return idle_rocking_config.strength_degrees if idle_rocking_config != null else 0.0
	set(value):
		_ensure_idle_rocking_config().strength_degrees = value
		_cleanup_idle_rocking_config()

var rocking_pivot_mode: int:
	get:
		return idle_rocking_config.pivot_mode if idle_rocking_config != null else 0
	set(value):
		_ensure_idle_rocking_config().pivot_mode = value
		_cleanup_idle_rocking_config()

var rocking_pivot_offset: Vector2:
	get:
		return idle_rocking_config.pivot_offset if idle_rocking_config != null else Vector2.ZERO
	set(value):
		_ensure_idle_rocking_config().pivot_offset = value
		_cleanup_idle_rocking_config()

var rocking_sound: AudioStream:
	get:
		return idle_rocking_config.sound if idle_rocking_config != null else null
	set(value):
		_ensure_idle_rocking_config().sound = value
		_cleanup_idle_rocking_config()

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
	var player := get_tree().get_first_node_in_group(GroupNames.PLAYER) as Node2D
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

func _ensure_unique_intro_config():
	if unique_intro_config == null:
		unique_intro_config = FridgeUniqueIntroConfigScript.new()
	return unique_intro_config

func _ensure_code_lock_config():
	if code_lock_config == null:
		code_lock_config = FridgeCodeLockConfigScript.new()
	return code_lock_config

func _ensure_lab_requirement_config():
	if lab_requirement_config == null:
		lab_requirement_config = FridgeLabRequirementConfigScript.new()
	return lab_requirement_config

func _ensure_teleport_config():
	if teleport_config == null:
		teleport_config = FridgeTeleportConfigScript.new()
	return teleport_config

func _ensure_idle_rocking_config():
	if idle_rocking_config == null:
		idle_rocking_config = IdleRockingConfigScript.new()
	return idle_rocking_config

func _cleanup_lab_requirement_config() -> void:
	if lab_requirement_config == null:
		return
	var has_ids: bool = not lab_requirement_config.required_lab_completion_ids.is_empty()
	var has_custom_message: bool = lab_requirement_config.required_message.strip_edges() != "" and lab_requirement_config.required_message != DEFAULT_LAB_REQUIRED_MESSAGE
	if not lab_requirement_config.require_any_lab_completion and not has_ids and not has_custom_message:
		lab_requirement_config = null

func _cleanup_code_lock_config() -> void:
	if code_lock_config == null:
		return
	var has_custom_message: bool = code_lock_config.access_code_failed_message.strip_edges() != ""
	if not code_lock_config.enabled and not has_custom_message:
		code_lock_config = null

func _cleanup_teleport_config() -> void:
	if teleport_config != null and teleport_config.target.is_empty():
		teleport_config = null

func _cleanup_idle_rocking_config() -> void:
	if idle_rocking_config == null:
		return
	var is_default_cycle := is_equal_approx(idle_rocking_config.cycle_duration, 2.0)
	var is_default_strength := is_zero_approx(idle_rocking_config.strength_degrees)
	var is_default_pivot: bool = idle_rocking_config.pivot_mode == 0 and idle_rocking_config.pivot_offset == Vector2.ZERO
	if is_default_cycle and is_default_strength and is_default_pivot and idle_rocking_config.sound == null:
		idle_rocking_config = null
