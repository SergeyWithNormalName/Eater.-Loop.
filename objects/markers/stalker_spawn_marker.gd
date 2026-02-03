extends Marker2D

const GROUP_NAME := "stalker_spawn"

func _ready() -> void:
	add_to_group(GROUP_NAME)
