extends "res://levels/cycles/level.gd"

const CYCLE_START_SUBTITLE := "Мне что-то не нравится, я должен БЕЖАТЬ"

var _cycle_start_subtitle_shown: bool = false

func _ready() -> void:
	super._ready()
	call_deferred("_show_cycle_start_subtitle")

func _show_cycle_start_subtitle() -> void:
	if _cycle_start_subtitle_shown:
		return
	_cycle_start_subtitle_shown = true
	if UIMessage == null:
		return
	if UIMessage.has_method("show_subtitle"):
		UIMessage.show_subtitle(CYCLE_START_SUBTITLE)
	elif UIMessage.has_method("show_text"):
		UIMessage.show_text(CYCLE_START_SUBTITLE)
