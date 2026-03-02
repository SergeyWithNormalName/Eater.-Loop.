extends Node

const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGE_RUSSIAN := "ru"
const LANGUAGE_ENGLISH := "en"
const WINDOW_TITLE_RU := "Едок. Петля."
const WINDOW_TITLE_EN := "Eater. Loop."
const CIS_COUNTRY_CODES := [
	"RU", # Russia
	"BY", # Belarus
	"KZ", # Kazakhstan
	"KG", # Kyrgyzstan
	"TJ", # Tajikistan
	"TM", # Turkmenistan
	"UZ", # Uzbekistan
	"AZ", # Azerbaijan
	"AM", # Armenia
	"MD", # Moldova
	"UA", # Ukraine
]

signal language_changed(language: String)

var _master_volume_db: float = -6.0
var _music_volume_db: float = -10.0
var _sounds_volume_db: float = -6.0
var _fullscreen: bool = false
var _vsync: bool = true
var _language: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_load_settings()
	if _language == "":
		_language = _detect_default_language()
	_apply_all()
	_save_settings()

func get_master_volume_db() -> float:
	return _master_volume_db

func get_music_volume_db() -> float:
	return _music_volume_db

func get_sounds_volume_db() -> float:
	return _sounds_volume_db

func get_sfx_volume_db() -> float:
	return get_sounds_volume_db()

func get_fullscreen() -> bool:
	return _fullscreen

func get_vsync() -> bool:
	return _vsync

func get_language() -> String:
	return _language

func set_master_volume_db(value: float) -> void:
	_master_volume_db = clamp(value, -80.0, 0.0)
	_apply_master_volume()
	_save_settings()

func set_music_volume_db(value: float) -> void:
	_music_volume_db = clamp(value, -80.0, 0.0)
	_apply_music_volume()
	_save_settings()

func set_sounds_volume_db(value: float) -> void:
	_sounds_volume_db = clamp(value, -80.0, 0.0)
	_apply_sounds_volume()
	_save_settings()

func set_sfx_volume_db(value: float) -> void:
	set_sounds_volume_db(value)

func set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	_apply_fullscreen()
	_save_settings()

func set_vsync(enabled: bool) -> void:
	_vsync = enabled
	_apply_vsync()
	_save_settings()

func set_language(language: String) -> void:
	var normalized := _normalize_language(language)
	if _language == normalized:
		return
	_language = normalized
	_apply_language()
	_save_settings()

func _ensure_audio_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("Sounds")

func _ensure_bus(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		return
	AudioServer.add_bus(AudioServer.get_bus_count())
	index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")

func _apply_all() -> void:
	_apply_language()
	_apply_master_volume()
	_apply_music_volume()
	_apply_sounds_volume()
	_apply_fullscreen()
	_apply_vsync()

func _apply_language() -> void:
	var locale := "ru_RU" if _language == LANGUAGE_RUSSIAN else "en_US"
	var locale_changed := TranslationServer.get_locale() != locale
	if locale_changed:
		TranslationServer.set_locale(locale)
	DisplayServer.window_set_title(WINDOW_TITLE_RU if _language == LANGUAGE_RUSSIAN else WINDOW_TITLE_EN)
	if locale_changed:
		emit_signal("language_changed", _language)

func _apply_master_volume() -> void:
	var index := AudioServer.get_bus_index("Master")
	if index != -1:
		AudioServer.set_bus_volume_db(index, _master_volume_db)

func _apply_music_volume() -> void:
	var index := AudioServer.get_bus_index("Music")
	if index != -1:
		AudioServer.set_bus_volume_db(index, _music_volume_db)

func _apply_sounds_volume() -> void:
	var index := AudioServer.get_bus_index("Sounds")
	if index != -1:
		AudioServer.set_bus_volume_db(index, _sounds_volume_db)

func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _apply_vsync() -> void:
	var mode := DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_master_volume_db = config.get_value("audio", "master_db", _master_volume_db)
	_music_volume_db = config.get_value("audio", "music_db", _music_volume_db)
	if config.has_section_key("audio", "sounds_db"):
		_sounds_volume_db = config.get_value("audio", "sounds_db", _sounds_volume_db)
	else:
		_sounds_volume_db = config.get_value("audio", "sfx_db", _sounds_volume_db)
	_fullscreen = config.get_value("video", "fullscreen", _fullscreen)
	_vsync = config.get_value("video", "vsync", _vsync)
	var saved_language := String(config.get_value("general", "language", "")).strip_edges()
	if saved_language != "":
		_language = _normalize_language(saved_language)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_db", _master_volume_db)
	config.set_value("audio", "music_db", _music_volume_db)
	config.set_value("audio", "sounds_db", _sounds_volume_db)
	config.set_value("audio", "sfx_db", _sounds_volume_db)
	config.set_value("video", "fullscreen", _fullscreen)
	config.set_value("video", "vsync", _vsync)
	config.set_value("general", "language", _language)
	config.save(SETTINGS_PATH)

func _detect_default_language() -> String:
	var locale := OS.get_locale().strip_edges()
	if locale == "":
		return LANGUAGE_ENGLISH

	locale = locale.replace("-", "_")
	var parts := locale.split("_", false)
	var language_part := parts[0].to_lower() if not parts.is_empty() else ""
	var country_part := parts[1].to_upper() if parts.size() >= 2 else ""

	if language_part == LANGUAGE_RUSSIAN:
		return LANGUAGE_RUSSIAN
	if CIS_COUNTRY_CODES.has(country_part):
		return LANGUAGE_RUSSIAN
	return LANGUAGE_ENGLISH

func _normalize_language(language: String) -> String:
	var value := language.strip_edges().to_lower()
	if value.begins_with(LANGUAGE_RUSSIAN):
		return LANGUAGE_RUSSIAN
	if value.begins_with(LANGUAGE_ENGLISH):
		return LANGUAGE_ENGLISH
	return LANGUAGE_ENGLISH
