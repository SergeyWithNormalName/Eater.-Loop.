extends "res://levels/cycles/level_11_end.gd"

func _ready() -> void:
	super._ready()
	_stop_carried_music()

func _stop_carried_music() -> void:
	if MusicManager == null:
		return
	if MusicManager.has_method("clear_chase_music_sources"):
		MusicManager.clear_chase_music_sources(0.0)
	if MusicManager.has_method("clear_stack"):
		MusicManager.clear_stack()
	if MusicManager.has_method("reset_base_music_state"):
		MusicManager.reset_base_music_state()
	elif MusicManager.has_method("stop_music"):
		MusicManager.stop_music(0.0)
