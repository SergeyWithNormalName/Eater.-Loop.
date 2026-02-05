extends AudioStreamPlayer

@export_group("Музыка")
## Запустить музыку уровня при старте сцены.
@export var play_on_ready: bool = true
## Длительность плавного перехода.
@export_range(0.0, 10.0, 0.1) var fade_time: float = 1.0
## Продолжать музыку после смены уровня.
@export var continue_on_level_change: bool = true

func _ready() -> void:
	autoplay = false
	if not play_on_ready:
		return
	if stream == null:
		return
	if MusicManager:
		MusicManager.play_ambient_music(stream, fade_time, volume_db)

func _exit_tree() -> void:
	if continue_on_level_change:
		return
	if MusicManager:
		MusicManager.stop_ambient_music(stream, fade_time)
