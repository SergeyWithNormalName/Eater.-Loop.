class_name MusicMixSettings
extends Resource

## Настройки микса для типов музыки (дБ оффсеты).

@export_range(-40.0, 20.0, 0.1) var ambient_db_offset: float = -6.0
@export_range(-40.0, 20.0, 0.1) var distortion_db_offset: float = 0.0
@export_range(-40.0, 20.0, 0.1) var event_db_offset: float = 0.0
@export_range(-40.0, 20.0, 0.1) var chase_db_offset: float = 0.0
@export_range(-40.0, 20.0, 0.1) var minigame_db_offset: float = 0.0
@export_range(-40.0, 20.0, 0.1) var pause_db_offset: float = 0.0
@export_range(-40.0, 20.0, 0.1) var menu_db_offset: float = 0.0
