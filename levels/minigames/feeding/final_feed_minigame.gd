extends "res://levels/minigames/feeding/feed_minigame.gd"

signal stage_changed(stage_number: int, total_stages: int)

@export_group("Stage Glitch")
@export_range(0.1, 6.0, 0.1) var stage_glitch_duration: float = 1.1
@export_range(0.0, 1.0, 0.05) var stage_glitch_peak_intensity: float = 1.0
@export_range(0.0, 2.0, 0.05) var stage_pause_after_glitch: float = 0.25
@export_range(0.0, 0.2, 0.005) var stage_glitch_shake_power: float = 0.07
@export_range(0.0, 0.3, 0.01) var stage_glitch_color_bleeding: float = 0.11
@export_range(0.0, 180.0, 1.0) var stage_glitch_lines: float = 125.0
@export_range(0.0, 2.0, 0.05) var stage_glitch_vignette: float = 1.45
@export var stage_glitch_sfx: AudioStream = preload("res://music/MyHorrorHit_3.wav")
@export_range(-80.0, 6.0, 0.1) var stage_glitch_sfx_volume_db: float = 0.0

const STAGE_GLITCH_SHADER := preload("res://shaders/distortion_transition.gdshader")

var _stages: Array[Dictionary] = []
var _stage_index: int = -1
var _stage_transition_active: bool = false

var _chosen_music: AudioStream = null
var _chosen_win: AudioStream = null
var _chosen_eat: AudioStream = null
var _chosen_bg: Texture2D = null

var _stage_glitch_rect: ColorRect = null
var _stage_glitch_material: ShaderMaterial = null

func _ready() -> void:
	super._ready()
	_create_stage_glitch_overlay()

func setup_final_stages(stages: Array, music: AudioStream, win_sound: AudioStream, eat_sound_override: AudioStream = null, bg_override: Texture2D = null) -> void:
	_stages = _sanitize_stages(stages)
	if _stages.is_empty():
		push_error("FinalFeedMinigame: не переданы валидные этапы.")
		return

	_chosen_music = music
	_chosen_win = win_sound
	_chosen_eat = eat_sound_override
	_chosen_bg = bg_override

	_stage_index = -1
	_stage_transition_active = false
	_start_next_stage()

func allows_distortion_overlay() -> bool:
	# Во время финальной мини-игры оставляем только локальные глитчи,
	# чтобы искажения квартиры были заметнее после выхода в мир.
	return false

func _on_food_eaten() -> void:
	if _stage_transition_active:
		return
	_eaten_count += 1
	if eat_sfx_player.stream:
		eat_sfx_player.play()
	if _eaten_count < food_needed or _is_won:
		return
	if _stage_index >= _stages.size() - 1:
		_win()
		return
	_stage_transition_active = true
	_play_stage_glitch()

func _start_next_stage() -> void:
	_stage_index += 1
	if _stage_index >= _stages.size():
		_win()
		return
	_spawn_stage(_stage_index)
	stage_changed.emit(_stage_index + 1, _stages.size())

func _spawn_stage(index: int) -> void:
	_clear_food_nodes()
	_eaten_count = 0
	_is_won = false

	var stage: Dictionary = _stages[index]
	var stage_face := stage.get("face", null) as Texture2D
	var stage_food_count := int(stage.get("food_count", 5))
	var stage_food_scenes: Array[PackedScene] = []
	var raw_food_scenes: Variant = stage.get("food_scenes", [])
	if raw_food_scenes is Array:
		for scene_variant in raw_food_scenes:
			if scene_variant is PackedScene and scene_variant != null:
				stage_food_scenes.append(scene_variant)

	super.setup_game(
		stage_face,
		maxi(1, stage_food_count),
		_chosen_music,
		_chosen_win,
		_chosen_eat,
		_chosen_bg,
		stage_food_scenes
	)

func _clear_food_nodes() -> void:
	for child in food_container.get_children():
		if child == null:
			continue
		child.free()

func _sanitize_stages(raw_stages: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in raw_stages:
		if not (item is Dictionary):
			continue
		var source := item as Dictionary
		var food_list: Array[PackedScene] = []
		var raw_food: Variant = source.get("food_scenes", [])
		if raw_food is Array:
			for scene_variant in raw_food:
				if scene_variant is PackedScene and scene_variant != null:
					food_list.append(scene_variant)
		if food_list.is_empty():
			continue
		var stage_face := source.get("face", null) as Texture2D
		var stage_count := maxi(1, int(source.get("food_count", food_list.size())))
		result.append({
			"face": stage_face,
			"food_count": stage_count,
			"food_scenes": food_list,
		})
	return result

func _create_stage_glitch_overlay() -> void:
	if _stage_glitch_rect != null:
		return
	_stage_glitch_rect = ColorRect.new()
	_stage_glitch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_glitch_rect.visible = false

	_stage_glitch_material = ShaderMaterial.new()
	_stage_glitch_material.shader = STAGE_GLITCH_SHADER
	_stage_glitch_rect.material = _stage_glitch_material
	_stage_glitch_rect.z_index = 100
	add_child(_stage_glitch_rect)

	_stage_glitch_material.set_shader_parameter("intensity", 0.0)
	_stage_glitch_material.set_shader_parameter("shake_power", stage_glitch_shake_power)
	_stage_glitch_material.set_shader_parameter("color_bleeding", stage_glitch_color_bleeding)
	_stage_glitch_material.set_shader_parameter("glitch_lines", stage_glitch_lines)
	_stage_glitch_material.set_shader_parameter("vignette_intensity", stage_glitch_vignette)
	_stage_glitch_material.set_shader_parameter("desaturation", 0.82)

func _play_stage_glitch() -> void:
	if _stage_glitch_rect == null or _stage_glitch_material == null:
		_start_next_stage()
		_complete_stage_transition_after_glitch()
		return
	_play_stage_glitch_sfx()
	_stage_glitch_rect.visible = true
	_set_stage_glitch_intensity(0.0)

	var half_duration := maxf(0.05, stage_glitch_duration * 0.5)
	var tween := create_tween()
	tween.tween_method(_set_stage_glitch_intensity, 0.0, stage_glitch_peak_intensity, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_stage_glitch_intensity, stage_glitch_peak_intensity, 0.0, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_finish_stage_glitch_overlay)

func _set_stage_glitch_intensity(value: float) -> void:
	if _stage_glitch_material == null:
		return
	_stage_glitch_material.set_shader_parameter("intensity", float(clamp(value, 0.0, 1.0)))

func _finish_stage_glitch_overlay() -> void:
	if _stage_glitch_rect != null:
		_stage_glitch_rect.visible = false
	_set_stage_glitch_intensity(0.0)
	if stage_pause_after_glitch > 0.0:
		get_tree().create_timer(stage_pause_after_glitch).timeout.connect(_finalize_stage_transition_after_glitch)
		return
	_finalize_stage_transition_after_glitch()

func _complete_stage_transition_after_glitch() -> void:
	_stage_transition_active = false

func _finalize_stage_transition_after_glitch() -> void:
	_complete_stage_transition_after_glitch()
	_start_next_stage()

func _play_stage_glitch_sfx() -> void:
	if stage_glitch_sfx == null:
		return
	if UIMessage != null and UIMessage.has_method("play_sfx"):
		UIMessage.play_sfx(stage_glitch_sfx, stage_glitch_sfx_volume_db, 1.0)

func _win() -> void:
	_is_won = true
	if MinigameController:
		MinigameController.stop_minigame_music(music_suspend_fade_time)
	# Для финальной feeding-миниигры в level_14_end отключаем win-sfx (Poel_1.wav).
	get_tree().create_timer(finish_delay).timeout.connect(_close_game)
