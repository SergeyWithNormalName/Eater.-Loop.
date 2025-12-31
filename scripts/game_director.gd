extends Node

@export var time_until_distortion: float = 20.0  # секунд до "ломания"

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = time_until_distortion
	_timer.timeout.connect(_on_distortion_timeout)
	add_child(_timer)

	start_normal_phase()

func start_normal_phase() -> void:
	GameState.set_phase(GameState.Phase.NORMAL)
	_timer.start()
	print("GameDirector: NORMAL phase started, timer =", time_until_distortion)

func _on_distortion_timeout() -> void:
	GameState.set_phase(GameState.Phase.DISTORTED)
	print("GameDirector: DISTORTED phase started")
