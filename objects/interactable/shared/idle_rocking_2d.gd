extends Node
class_name IdleRocking2D

enum PivotMode {
	CENTERED,
	HANGING,
}

var _target_sprite: Sprite2D = null
var _cycle_duration: float = 2.0
var _strength_degrees: float = 0.0
var _pivot_mode: int = PivotMode.CENTERED
var _pivot_offset: Vector2 = Vector2.ZERO
var _rocking_sound: AudioStream = null
var _force_centered: bool = false

var _rocking_active: bool = false
var _rocking_elapsed: float = 0.0
var _rocking_base_rotation: float = 0.0
var _rocking_sound_player: AudioStreamPlayer2D = null
var _rocking_sound_connected: bool = false

func _ready() -> void:
	set_process(false)

func configure(
	target_sprite: Sprite2D,
	cycle_duration: float,
	strength_degrees: float,
	pivot_mode: int,
	pivot_offset: Vector2,
	rocking_sound: AudioStream
) -> void:
	_target_sprite = target_sprite
	_cycle_duration = cycle_duration
	_strength_degrees = strength_degrees
	_pivot_mode = pivot_mode
	_pivot_offset = pivot_offset
	_rocking_sound = rocking_sound
	apply_pivot()

func apply_pivot() -> void:
	if _target_sprite == null:
		return
	if _target_sprite.texture == null:
		return
	if _force_centered:
		_target_sprite.centered = true
		_target_sprite.offset = Vector2.ZERO
		return
	if _pivot_mode == PivotMode.HANGING:
		var tex_size := _target_sprite.texture.get_size()
		_target_sprite.centered = false
		_target_sprite.offset = Vector2(-tex_size.x * 0.5, 0.0) + _pivot_offset
		return
	_target_sprite.centered = true
	_target_sprite.offset = Vector2.ZERO

func start_if_configured() -> void:
	if _strength_degrees <= 0.0:
		return
	if _target_sprite == null:
		return
	if _rocking_active:
		return
	_rocking_active = true
	_rocking_elapsed = 0.0
	_rocking_base_rotation = _target_sprite.rotation
	_play_rocking_sound()
	set_process(true)

func stop() -> void:
	_rocking_active = false
	if _target_sprite != null:
		_target_sprite.rotation = _rocking_base_rotation
	if _rocking_sound_player != null:
		_rocking_sound_player.stop()
	set_process(false)

func apply_winch_release_state() -> void:
	stop()
	_force_centered = true
	_strength_degrees = 0.0
	_pivot_mode = PivotMode.CENTERED
	apply_pivot()

func set_strength_degrees(value: float) -> void:
	_strength_degrees = value

func set_pivot_mode(value: int) -> void:
	_pivot_mode = value
	apply_pivot()

func _process(delta: float) -> void:
	if not _rocking_active:
		return
	if _target_sprite == null:
		return
	_rocking_elapsed += delta
	var cycle := maxf(0.05, _cycle_duration)
	var angle := sin(_rocking_elapsed * TAU / cycle) * deg_to_rad(_strength_degrees)
	_target_sprite.rotation = _rocking_base_rotation + angle

func _play_rocking_sound() -> void:
	if _rocking_sound == null:
		return
	if _rocking_sound_player == null:
		_rocking_sound_player = AudioStreamPlayer2D.new()
		_rocking_sound_player.bus = "Sounds"
		_rocking_sound_player.volume_db = -12.0
		add_child(_rocking_sound_player)
		_rocking_sound_connected = false
	_rocking_sound_player.stream = _rocking_sound
	_rocking_sound_player.play()
	if not _rocking_sound_connected:
		_rocking_sound_player.finished.connect(_on_rocking_sound_finished)
		_rocking_sound_connected = true

func _on_rocking_sound_finished() -> void:
	if _rocking_active and _rocking_sound_player != null:
		_rocking_sound_player.play()
