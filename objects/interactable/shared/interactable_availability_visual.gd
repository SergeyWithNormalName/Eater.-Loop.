extends RefCounted
class_name InteractableAvailabilityVisual

var _sprite: Sprite2D = null
var _locked_texture: Texture2D = null
var _available_texture: Texture2D = null
var _lights: Array[CanvasItem] = []
var _noise_player: AudioStreamPlayer2D = null

func configure(
	sprite: Sprite2D,
	locked_texture: Texture2D,
	available_texture: Texture2D,
	lights: Array[CanvasItem],
	noise_player: AudioStreamPlayer2D = null
) -> void:
	_sprite = sprite
	_locked_texture = locked_texture
	_available_texture = available_texture
	_lights = []
	for light in lights:
		if light != null:
			_lights.append(light)
	_noise_player = noise_player

func apply(is_available: bool) -> void:
	if _sprite != null:
		if is_available and _available_texture != null:
			_sprite.texture = _available_texture
		elif not is_available and _locked_texture != null:
			_sprite.texture = _locked_texture
	for light in _lights:
		if light != null:
			light.visible = is_available
	_sync_noise_state(is_available)

func _sync_noise_state(is_available: bool) -> void:
	if _noise_player == null:
		return
	if not is_available:
		if _noise_player.playing:
			_noise_player.stop()
		return
	if _noise_player.stream == null:
		return
	if not _noise_player.playing:
		_noise_player.play()
