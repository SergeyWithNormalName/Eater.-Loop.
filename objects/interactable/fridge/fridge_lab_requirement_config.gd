extends Resource
class_name FridgeLabRequirementConfig

@export var require_any_lab_completion: bool = false
@export var required_lab_completion_ids: PackedStringArray = PackedStringArray()
@export var required_message: String = "Сначала нужно сделать лабораторную работу."
