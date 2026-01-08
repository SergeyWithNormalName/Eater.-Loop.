extends Node2D

@onready var label: Label = $Label
## Стартовое время в формате HH:MM.
@export var start_game_time: String = "01:20"
var _total_game_minutes: float = 0.0

func _ready() -> void:
	var parts = start_game_time.split(":")
	if parts.size() == 2:
		var hours = int(parts[0])
		var minutes = int(parts[1])
		_total_game_minutes = (hours * 60) + minutes
	else:
		_total_game_minutes = 60.0

func _process(_delta: float) -> void:
	var ratio = GameDirector.get_time_ratio()
	var current_minutes_left = _total_game_minutes * ratio
	
	var display_h = floor(current_minutes_left / 60)
	var display_m = floor(fmod(current_minutes_left, 60))
	
	label.text = "%d:%02d" % [display_h, display_m]
	
	if ratio < 0.2:
		label.modulate = Color(1, 0, 0)
	else:
		label.modulate = Color(1, 1, 1)
		
