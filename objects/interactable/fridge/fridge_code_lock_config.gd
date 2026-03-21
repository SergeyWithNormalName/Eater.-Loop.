extends Resource
class_name FridgeCodeLockConfig

@export var enabled: bool = true
@export var access_code: String = "1234"
@export var access_code_failed_message: String = ""
@export var code_lock_scene: PackedScene = preload("res://levels/minigames/ui/code_lock.tscn")
