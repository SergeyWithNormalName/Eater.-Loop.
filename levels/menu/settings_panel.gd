extends PanelContainer

signal closed

@onready var _master_slider: HSlider = $VBox/Content/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $VBox/Content/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $VBox/Content/SfxRow/SfxSlider
@onready var _fullscreen_check: CheckBox = $VBox/Content/FullscreenCheck
@onready var _vsync_check: CheckBox = $VBox/Content/VsyncCheck
@onready var _language_option: OptionButton = $VBox/Content/LanguageRow/LanguageOption
@onready var _back_button: Button = $VBox/BackButton

const LANGUAGE_ITEMS := [
	{"code": "ru", "label": "Русский"},
	{"code": "en", "label": "Английский"},
]

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_vsync_check.toggled.connect(_on_vsync_toggled)
	_language_option.item_selected.connect(_on_language_selected)
	if SettingsManager and SettingsManager.has_signal("language_changed"):
		SettingsManager.language_changed.connect(_on_language_changed)
	_sync_from_settings()

func focus_default() -> void:
	_master_slider.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_language_items()

func _on_back_pressed() -> void:
	emit_signal("closed")

func _sync_from_settings() -> void:
	if SettingsManager == null:
		return
	_master_slider.value = SettingsManager.get_master_volume_db()
	_music_slider.value = SettingsManager.get_music_volume_db()
	_sfx_slider.value = SettingsManager.get_sounds_volume_db()
	_fullscreen_check.button_pressed = SettingsManager.get_fullscreen()
	_vsync_check.button_pressed = SettingsManager.get_vsync()
	_refresh_language_items()

func _on_master_changed(value: float) -> void:
	if SettingsManager:
		SettingsManager.set_master_volume_db(value)

func _on_music_changed(value: float) -> void:
	if SettingsManager:
		SettingsManager.set_music_volume_db(value)

func _on_sfx_changed(value: float) -> void:
	if SettingsManager:
		SettingsManager.set_sounds_volume_db(value)

func _on_fullscreen_toggled(pressed: bool) -> void:
	if SettingsManager:
		SettingsManager.set_fullscreen(pressed)

func _on_vsync_toggled(pressed: bool) -> void:
	if SettingsManager:
		SettingsManager.set_vsync(pressed)

func _on_language_selected(index: int) -> void:
	if SettingsManager == null:
		return
	if index < 0 or index >= _language_option.get_item_count():
		return
	var language_code := String(_language_option.get_item_metadata(index))
	SettingsManager.set_language(language_code)
	_refresh_language_items()

func _on_language_changed(_language: String) -> void:
	_refresh_language_items()

func _refresh_language_items() -> void:
	if _language_option == null:
		return
	var selected_language := "en"
	if SettingsManager and SettingsManager.has_method("get_language"):
		selected_language = String(SettingsManager.get_language())
	var current_index := 0
	_language_option.clear()
	for i in range(LANGUAGE_ITEMS.size()):
		var item: Dictionary = LANGUAGE_ITEMS[i]
		var code := String(item.get("code", "en"))
		var label_key := String(item.get("label", ""))
		_language_option.add_item(tr(label_key))
		_language_option.set_item_metadata(i, code)
		if code == selected_language:
			current_index = i
	if _language_option.get_item_count() > 0:
		_language_option.select(current_index)
