extends Control

@export var ending_text: String = "Хорошая концовка"
@export_range(0.1, 20.0, 0.1) var display_duration: float = 3.8
@export_range(0.0, 5.0, 0.05) var text_fade_time: float = 0.9
@export_range(0.0, 5.0, 0.05) var transition_fade_time: float = 0.8
@export var next_scene: PackedScene = preload("res://levels/endings/ending_credits.tscn")

@onready var _title: Label = $CenterContainer/Title

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_music_for_ending()
	_apply_title_font()
	_title.text = ending_text
	_title.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_run_sequence()

func _run_sequence() -> void:
	await _wait_for_screen_fade_in()

	var fade_time := maxf(0.0, text_fade_time)
	if fade_time > 0.0:
		var fade_tween := create_tween()
		fade_tween.tween_property(_title, "modulate:a", 1.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await fade_tween.finished
	else:
		_title.modulate.a = 1.0

	var hold_time := maxf(0.1, display_duration)
	await get_tree().create_timer(hold_time).timeout

	if next_scene == null:
		return
	if UIMessage != null and UIMessage.has_method("change_scene_with_fade"):
		await UIMessage.change_scene_with_fade(next_scene, transition_fade_time, true)
		return
	get_tree().change_scene_to_packed(next_scene)

func _wait_for_screen_fade_in() -> void:
	if UIMessage == null or not UIMessage.has_method("is_screen_dark"):
		return
	var max_frames := 240
	var frames := 0
	while frames < max_frames and UIMessage.is_screen_dark(0.02):
		await get_tree().process_frame
		frames += 1

func _apply_title_font() -> void:
	var base_font = load("res://global/fonts/AmaticSC-Bold.ttf")
	if base_font == null:
		return
	var variation := FontVariation.new()
	variation.base_font = base_font
	variation.spacing_glyph = 3
	_title.add_theme_font_override("font", variation)

func _reset_music_for_ending() -> void:
	if MusicManager == null:
		return
	if MusicManager.has_method("stop_pause_menu_music"):
		MusicManager.stop_pause_menu_music(0.0)
	if MusicManager.has_method("clear_stack"):
		MusicManager.clear_stack()
	if MusicManager.has_method("reset_base_music_state"):
		MusicManager.reset_base_music_state()
	elif MusicManager.has_method("stop_music"):
		MusicManager.stop_music(0.0)
