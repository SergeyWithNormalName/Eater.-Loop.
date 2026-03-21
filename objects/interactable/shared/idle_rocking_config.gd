extends Resource
class_name IdleRockingConfig

@export_range(0.05, 60.0, 0.05) var cycle_duration: float = 2.0
@export_range(0.0, 45.0, 0.1) var strength_degrees: float = 0.0
@export_enum("Centered", "Hanging") var pivot_mode: int = 0
@export var pivot_offset: Vector2 = Vector2.ZERO
@export var sound: AudioStream
