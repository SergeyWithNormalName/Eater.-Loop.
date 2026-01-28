extends AudioStreamPlayer

@export_group("Музыка")
## Запустить музыку уровня при старте сцены.
@export var play_on_ready: bool = true
## Длительность плавного перехода.
@export_range(0.0, 10.0, 0.1) var fade_time: float = 1.0

func _ready() -> void:
	autoplay = false
	if not play_on_ready:
		return
	if stream == null:
		return
	if MusicManager:
		MusicManager.play_music(stream, fade_time, volume_db)
