extends "res://objects/interactable/fridge/fridge.gd"

signal ending_feeding_finished

@export var final_minigame_scene: PackedScene = preload("res://levels/minigames/feeding/final_feed_minigame.tscn")
@export var force_distortion_on_start: bool = true
@export_range(0.0, 30.0, 0.1) var distortion_trigger_delay: float = 5.0

const FACE_HAPPY := preload("res://levels/minigames/feeding/andreys_faces/HappyEat.png")
const FACE_BASIC := preload("res://levels/minigames/feeding/andreys_faces/BasicEat.png")
const FACE_SAD := preload("res://levels/minigames/feeding/andreys_faces/SadEat.png")

const FOOD_DUMPLING := preload("res://levels/minigames/feeding/food/dumpling/food_dumpling.tscn")
const FOOD_BURGER := preload("res://levels/minigames/feeding/food/burger/food_burger.tscn")
const FOOD_SHAURMA := preload("res://levels/minigames/feeding/food/shaurma/food_shaurma.tscn")
const FOOD_TORT := preload("res://levels/minigames/feeding/food/tort/food_tort.tscn")
const FOOD_COOKIE_A := preload("res://levels/minigames/feeding/food/cookie/food_cookie_1.tscn")
const FOOD_COOKIE_B := preload("res://levels/minigames/feeding/food/cookie/food_cookie_5.tscn")
const FOOD_MEAT := preload("res://levels/minigames/feeding/food/meet/food_meet.tscn")
const FOOD_CHICKEN := preload("res://levels/minigames/feeding/food/chiken/food_chicken.tscn")

var _distortion_forced: bool = false

func _start_feeding_process() -> void:
	_is_interacting = true

	if open_sound:
		_sfx_player.stream = open_sound
		_sfx_player.play()

	var game_scene := final_minigame_scene
	if game_scene == null:
		push_warning("FinalEndingFridge: не назначена финальная сцена feeding.")
		_finish_feeding_logic()
		_is_interacting = false
		return

	var game := game_scene.instantiate()
	_current_minigame = game
	attach_minigame(game)

	if force_distortion_on_start:
		_schedule_level_distortion()

	if game.has_method("setup_final_stages"):
		game.setup_final_stages(_build_stage_data(), bg_music, win_sound, eat_sound, background_texture)
	elif game.has_method("setup_game"):
		game.setup_game(andrey_face, food_count, bg_music, win_sound, eat_sound, background_texture, food_scenes)

	if game.has_signal("minigame_finished"):
		game.minigame_finished.connect(_on_feeding_finished)

func _finish_feeding_logic() -> void:
	super._finish_feeding_logic()
	ending_feeding_finished.emit()

func _force_level_distortion() -> void:
	if _distortion_forced:
		return
	_distortion_forced = true
	if GameDirector != null and GameDirector.has_method("trigger_distortion_now"):
		GameDirector.trigger_distortion_now()
		return
	if GameDirector != null and GameDirector.has_method("set_time_left"):
		GameDirector.set_time_left(0.0)

func _schedule_level_distortion() -> void:
	if _distortion_forced:
		return
	if distortion_trigger_delay > 0.0:
		await get_tree().create_timer(distortion_trigger_delay).timeout
	if not is_inside_tree():
		return
	_force_level_distortion()

func _build_stage_data() -> Array[Dictionary]:
	return [
		{
			"face": FACE_HAPPY,
			"food_count": 7,
			"food_scenes": [FOOD_DUMPLING],
		},
		{
			"face": FACE_BASIC,
			"food_count": 7,
			"food_scenes": [FOOD_CHICKEN, FOOD_MEAT],
		},
		{
			"face": FACE_BASIC,
			"food_count": 7,
			"food_scenes": [FOOD_SHAURMA, FOOD_BURGER],
		},
		{
			"face": FACE_SAD,
			"food_count": 6,
			"food_scenes": [FOOD_TORT, FOOD_BURGER],
		},
		{
			# Заглушка под будущий более неприятный этап.
			"face": FACE_SAD,
			"food_count": 8,
			"food_scenes": [FOOD_COOKIE_A, FOOD_COOKIE_B],
		},
	]
