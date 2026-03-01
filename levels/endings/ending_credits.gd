extends Control

@export_group("Flow")
@export_range(5.0, 240.0, 1.0) var scroll_speed: float = 42.0
@export_range(0.0, 6.0, 0.1) var end_hold_time: float = 2.3
@export_range(0.0, 6.0, 0.1) var return_fade_time: float = 0.9
@export var return_scene: PackedScene = preload("res://levels/menu/main_menu.tscn")
@export var esc_exit_hint_text: String = "Нажмите ещё раз, чтобы выйти"
@export_range(0.3, 5.0, 0.1) var esc_exit_hint_window: float = 1.8
@export_range(10, 120, 1) var esc_exit_hint_font_size: int = 52

@export_group("Credits Audio")
@export var credits_music: AudioStream
@export_range(-80.0, 6.0, 0.1) var credits_music_volume_db: float = -14.0
@export_range(0.0, 10.0, 0.1) var credits_music_fade_time: float = 1.0

@onready var _credits_root: VBoxContainer = $CreditsViewport/CreditsRoot
@onready var _exit_hint_label: Label = $ExitHint

const MAIN_MENU_SCENE_PATH := "res://levels/menu/main_menu.tscn"

var _scroll_started: bool = false
var _is_finishing: bool = false
var _end_y: float = 0.0
var _esc_confirm_pending: bool = false
var _esc_confirm_token: int = 0
var _return_transition_started: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_label_fonts()
	_play_credits_music()
	_set_pause_block(true)
	_hide_exit_hint()
	call_deferred("_start_scroll")

func _process(delta: float) -> void:
	if not _scroll_started or _is_finishing:
		return
	_credits_root.position.y -= scroll_speed * delta
	if _credits_root.position.y <= _end_y:
		_finish_credits()

func _start_scroll() -> void:
	await get_tree().process_frame
	var viewport_size := get_viewport_rect().size
	var content_height := _credits_root.size.y
	_credits_root.position.y = viewport_size.y + 120.0
	_end_y = -content_height - 120.0
	_scroll_started = true

func _finish_credits() -> void:
	if _is_finishing:
		return
	_is_finishing = true
	_esc_confirm_pending = false
	_esc_confirm_token += 1
	_hide_exit_hint()
	if end_hold_time > 0.0:
		get_tree().create_timer(end_hold_time).timeout.connect(_perform_return_transition)
		return
	_perform_return_transition()

func _input(event: InputEvent) -> void:
	if _is_finishing:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if not _is_escape_event(event):
		return
	get_viewport().set_input_as_handled()
	if _esc_confirm_pending:
		_exit_to_menu_now()
		return
	_start_escape_confirm_window()

func _is_escape_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.physical_keycode == KEY_ESCAPE or key_event.keycode == KEY_ESCAPE

func _exit_to_menu_now() -> void:
	if _is_finishing:
		return
	_is_finishing = true
	_esc_confirm_pending = false
	_esc_confirm_token += 1
	_hide_exit_hint()
	_perform_return_transition()

func _exit_tree() -> void:
	_set_pause_block(false)

func _play_credits_music() -> void:
	if credits_music == null:
		return
	if MusicManager == null:
		return
	MusicManager.play_ambient_music(credits_music, credits_music_fade_time, credits_music_volume_db)

func _stop_credits_music() -> void:
	if credits_music == null:
		return
	if MusicManager == null:
		return
	MusicManager.stop_ambient_music(credits_music, credits_music_fade_time)

func _apply_label_fonts() -> void:
	var title_font = load("res://global/fonts/AmaticSC-Bold.ttf")
	var body_font = load("res://global/fonts/AmaticSC-Regular.ttf")
	_apply_exit_hint_style(title_font, body_font)
	if title_font != null and has_node("CreditsViewport/CreditsRoot/Heading"):
		var heading := get_node("CreditsViewport/CreditsRoot/Heading") as Label
		if heading != null:
			var variation := FontVariation.new()
			variation.base_font = title_font
			variation.spacing_glyph = 3
			heading.add_theme_font_override("font", variation)
	if body_font == null:
		return
	var labels := get_tree().get_nodes_in_group("ending_credit_label")
	for node in labels:
		if not (node is Label):
			continue
		var label := node as Label
		if label.name == "Heading":
			continue
		var variation := FontVariation.new()
		variation.base_font = body_font
		variation.spacing_glyph = 2
		label.add_theme_font_override("font", variation)

func _set_pause_block(blocked: bool) -> void:
	if PauseManager == null:
		return
	if PauseManager.has_method("set_pause_blocked"):
		PauseManager.set_pause_blocked(self, blocked)

func _apply_exit_hint_style(title_font: Font, body_font: Font) -> void:
	if _exit_hint_label == null:
		return
	_exit_hint_label.add_theme_font_size_override("font_size", esc_exit_hint_font_size)
	_exit_hint_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_exit_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_exit_hint_label.add_theme_constant_override("outline_size", 2)
	_exit_hint_label.add_theme_constant_override("shadow_offset_x", 3)
	_exit_hint_label.add_theme_constant_override("shadow_offset_y", 3)
	var hint_font: Font = title_font if title_font != null else body_font
	if hint_font == null:
		return
	var variation := FontVariation.new()
	variation.base_font = hint_font
	variation.spacing_glyph = 2
	_exit_hint_label.add_theme_font_override("font", variation)

func _show_exit_hint() -> void:
	if _exit_hint_label == null:
		return
	_exit_hint_label.text = esc_exit_hint_text
	_exit_hint_label.visible = true

func _hide_exit_hint() -> void:
	if _exit_hint_label == null:
		return
	_exit_hint_label.visible = false

func _start_escape_confirm_window() -> void:
	_esc_confirm_pending = true
	_esc_confirm_token += 1
	var token := _esc_confirm_token
	_show_exit_hint()
	get_tree().create_timer(esc_exit_hint_window).timeout.connect(func() -> void:
		if token != _esc_confirm_token:
			return
		if _is_finishing:
			return
		_esc_confirm_pending = false
		_hide_exit_hint()
	)

func _perform_return_transition() -> void:
	if _return_transition_started:
		return
	_return_transition_started = true
	_esc_confirm_pending = false
	_esc_confirm_token += 1
	_hide_exit_hint()
	get_tree().paused = false
	_stop_credits_music()
	if UIMessage != null and UIMessage.has_method("play_fade_sequence") and return_fade_time > 0.0:
		var token := _esc_confirm_token
		UIMessage.play_fade_sequence(
			return_fade_time,
			return_fade_time,
			Callable(self, "_change_to_return_scene"),
			Callable(self, "_on_return_fade_finished").bind(token)
		)
		return
	_change_to_return_scene()

func _change_to_return_scene() -> void:
	var target_path := _resolve_return_scene_path()
	var tree := get_tree()
	if tree == null:
		_return_transition_started = false
		_is_finishing = false
		return
	var err := tree.change_scene_to_file(target_path)
	if err == OK:
		return
	var menu_scene := load(MAIN_MENU_SCENE_PATH) as PackedScene
	if menu_scene != null:
		tree.change_scene_to_packed(menu_scene)
		return
	_return_transition_started = false
	_is_finishing = false

func _resolve_return_scene_path() -> String:
	return MAIN_MENU_SCENE_PATH

func _on_return_fade_finished(token: int) -> void:
	if token != _esc_confirm_token:
		return
	# Если сцена по какой-то причине не сменилась, разблокируем титры и позволяем повторить выход.
	if get_tree() != null and get_tree().current_scene == self:
		_return_transition_started = false
		_is_finishing = false
		_esc_confirm_pending = false
		_hide_exit_hint()
