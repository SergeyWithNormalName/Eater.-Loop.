class_name MinigameSettings
extends Resource

@export var pause_game: bool = false
@export var enable_gamepad_cursor: bool = true
@export var gamepad_cursor_speed: float = 800.0
@export var time_limit: float = -1.0
@export var music_stream: AudioStream
@export var music_volume_db: float = 999.0
@export var music_fade_time: float = 0.3
@export var suspend_music: bool = false
@export var auto_finish_on_timeout: bool = false
@export var stop_music_on_finish: bool = false
@export var block_player_movement: bool = true
@export var allow_pause_menu: bool = true
@export var allow_cancel_action: bool = false
