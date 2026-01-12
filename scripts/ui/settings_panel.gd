extends PanelContainer

signal closed

@onready var _master_slider: HSlider = $VBox/Content/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $VBox/Content/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $VBox/Content/SfxRow/SfxSlider
@onready var _fullscreen_check: CheckBox = $VBox/Content/FullscreenCheck
@onready var _vsync_check: CheckBox = $VBox/Content/VsyncCheck
@onready var _back_button: Button = $VBox/BackButton

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_vsync_check.toggled.connect(_on_vsync_toggled)
	_sync_from_settings()

func focus_default() -> void:
	_master_slider.grab_focus()

func _on_back_pressed() -> void:
	emit_signal("closed")

func _sync_from_settings() -> void:
	if SettingsManager == null:
		return
	_master_slider.value = SettingsManager.get_master_volume_db()
	_music_slider.value = SettingsManager.get_music_volume_db()
	_sfx_slider.value = SettingsManager.get_sfx_volume_db()
	_fullscreen_check.button_pressed = SettingsManager.get_fullscreen()
	_vsync_check.button_pressed = SettingsManager.get_vsync()

func _on_master_changed(value: float) -> void:
	if SettingsManager:
		SettingsManager.set_master_volume_db(value)

func _on_music_changed(value: float) -> void:
	if SettingsManager:
		SettingsManager.set_music_volume_db(value)

func _on_sfx_changed(value: float) -> void:
	if SettingsManager:
		SettingsManager.set_sfx_volume_db(value)

func _on_fullscreen_toggled(pressed: bool) -> void:
	if SettingsManager:
		SettingsManager.set_fullscreen(pressed)

func _on_vsync_toggled(pressed: bool) -> void:
	if SettingsManager:
		SettingsManager.set_vsync(pressed)
