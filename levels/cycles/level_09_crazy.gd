extends "res://levels/cycles/level.gd"

const CYCLE_START_SUBTITLE := "Мне что-то не нравится, я должен БЕЖАТЬ"

func _ready() -> void:
	show_start_subtitle = true
	start_subtitle_text = CYCLE_START_SUBTITLE
	super._ready()
