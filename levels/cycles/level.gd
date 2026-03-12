extends Node2D
class_name CycleLevel

## Cycle number for this level.
@export var cycle_number: int = 1
## Timer duration in seconds (0 = disabled).
@export var timer_duration: float = 0.0

@export_group("Стартовая подсказка")
## Показывать подсказку при входе на уровень.
@export var show_start_hint: bool = false
## Текст стартовой подсказки.
@export_multiline var start_hint_text: String = ""
## Картинка для подсказки (опционально).
@export var start_hint_texture: Texture2D
## Ставить игру на паузу при подсказке.
@export var pause_on_start_hint: bool = true

@export_group("Стартовые субтитры")
## Показывать субтитр при старте уровня.
@export var show_start_subtitle: bool = false
## Текст стартового субтитра.
@export_multiline var start_subtitle_text: String = ""
## Длительность стартового субтитра (<= 0 использует дефолт UIMessage).
@export var start_subtitle_duration: float = -1.0
## Макс. ожидание завершения затемнения перед показом субтитра (сек), <= 0 без лимита.
@export var start_subtitle_wait_for_fade_timeout: float = 6.0

@export_group("Респавн затемнение")
## Показывать затемнение при респавне после смерти.
@export var respawn_blackout_enabled: bool = true
## Длительность чёрного экрана при респавне (сек), < 0 = авто (по длине wake SFX).
@export var respawn_blackout_hold_duration: float = -1.0
## Длительность проявления из чёрного после респавна (сек).
@export var respawn_blackout_fade_in_duration: float = 0.4

@export_group("Условный Респавн")
## Маркер, у которого нужно возродить игрока, если в цикле уже был успешный холодильник.
@export var fridge_interacted_spawn_marker_path: NodePath

const DEFAULT_WAKE_SFX_PATH := "res://objects/interactable/bed/OutOfBed.wav"
const DEFAULT_BLACKOUT_FALLBACK := 1.0

var _start_subtitle_shown: bool = false
var _cached_default_wake_blackout_duration: float = -1.0

func _ready() -> void:
	call_deferred("_apply_conditional_respawn_position")
	call_deferred("_run_pending_respawn_blackout")
	if show_start_hint and start_hint_text.strip_edges() != "":
		call_deferred("_show_start_hint")
	if show_start_subtitle and start_subtitle_text.strip_edges() != "":
		call_deferred("_show_start_subtitle")

func get_cycle_number() -> int:
	return cycle_number

func get_timer_duration() -> float:
	return timer_duration

func _show_start_hint() -> void:
	if not show_start_hint:
		return
	var text := start_hint_text.strip_edges()
	if text == "":
		return
	var attempts := 0
	while attempts < 3:
		var viewport_size := get_viewport().get_visible_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			break
		await get_tree().process_frame
		attempts += 1
	UIMessage.show_hint(text, start_hint_texture, pause_on_start_hint)

func should_show_start_subtitle() -> bool:
	return true

func _show_start_subtitle() -> void:
	if _start_subtitle_shown:
		return
	if not show_start_subtitle:
		return
	var text := start_subtitle_text.strip_edges()
	if text == "":
		return
	if not should_show_start_subtitle():
		return
	await _wait_until_screen_is_not_dark()
	if not should_show_start_subtitle():
		return
	if UIMessage == null:
		return
	_start_subtitle_shown = true
	if UIMessage.has_method("show_dialogue"):
		UIMessage.show_dialogue(text, null, start_subtitle_duration)
	elif UIMessage.has_method("show_subtitle"):
		UIMessage.show_subtitle(text, start_subtitle_duration)
	elif UIMessage.has_method("show_text"):
		UIMessage.show_text(text, start_subtitle_duration)

func _apply_conditional_respawn_position() -> void:
	if fridge_interacted_spawn_marker_path == NodePath(""):
		return
	if CycleState == null or not CycleState.has_method("is_fridge_interacted"):
		return
	if not bool(CycleState.is_fridge_interacted()):
		return
	var marker := get_node_or_null(fridge_interacted_spawn_marker_path) as Node2D
	if marker == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	player.global_position = marker.global_position

func _wait_until_screen_is_not_dark() -> void:
	if UIMessage == null:
		return
	if not UIMessage.has_method("is_screen_dark"):
		return
	var remaining_frames := -1
	if start_subtitle_wait_for_fade_timeout > 0.0:
		remaining_frames = maxi(1, int(ceil(start_subtitle_wait_for_fade_timeout * 60.0)))
	while bool(UIMessage.call("is_screen_dark", 0.02)):
		if remaining_frames == 0:
			return
		await get_tree().process_frame
		if remaining_frames > 0:
			remaining_frames -= 1

func _run_pending_respawn_blackout() -> void:
	if not _consume_pending_respawn_blackout():
		return
	if UIMessage == null:
		return
	var hold_duration := _resolve_respawn_blackout_hold_duration()
	if UIMessage.has_method("fade_out"):
		await UIMessage.fade_out(0.0)
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
	if UIMessage.has_method("fade_in"):
		await UIMessage.fade_in(maxf(0.0, respawn_blackout_fade_in_duration))

func _consume_pending_respawn_blackout() -> bool:
	if CycleState == null:
		return false
	return bool(CycleState.consume_pending_respawn_blackout()) and respawn_blackout_enabled

func _resolve_respawn_blackout_hold_duration() -> float:
	if respawn_blackout_hold_duration >= 0.0:
		return respawn_blackout_hold_duration
	return _resolve_default_wake_blackout_duration()

func _resolve_default_wake_blackout_duration() -> float:
	if _cached_default_wake_blackout_duration >= 0.0:
		return _cached_default_wake_blackout_duration
	var wake_sfx := load(DEFAULT_WAKE_SFX_PATH) as AudioStream
	if wake_sfx != null:
		var sfx_length := wake_sfx.get_length()
		if sfx_length > 0.0:
			_cached_default_wake_blackout_duration = sfx_length
			return _cached_default_wake_blackout_duration
	_cached_default_wake_blackout_duration = DEFAULT_BLACKOUT_FALLBACK
	return _cached_default_wake_blackout_duration

func handle_custom_death_screen() -> bool:
	return false
