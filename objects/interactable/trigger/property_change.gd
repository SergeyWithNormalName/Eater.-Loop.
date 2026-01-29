@tool
extends Resource
class_name PropertyChange

## Путь к узлу, в котором меняем свойство.
@export var target: NodePath
## Быстрый выбор свойства из списка (заполнит property_name).
@export_enum(
	"is_locked",
	"locked_message",
	"door_locked_message",
	"visible",
	"enabled",
	"energy",
	"position",
	"scale",
	"modulate",
	"z_index",
	"target_marker"
) var property_preset: String = "is_locked"
## Имя свойства для изменения.
@export var property_name: String
## Значение, которое будет установлено.
@export var value: Variant

func _set(property: StringName, value_in: Variant) -> bool:
	if property == "property_preset":
		property_preset = value_in
		if property_preset != "":
			property_name = property_preset
		return true
	return false
