@tool
extends Resource
class_name PropertyChange

@export var target: NodePath
@export_enum(
	"is_locked",
	"locked_message",
	"visible",
	"enabled",
	"energy",
	"position",
	"scale",
	"modulate",
	"z_index",
	"target_marker",
	"target_scene",
	"use_scene_change"
) var property_preset: String = "is_locked"
@export var property_name: String
@export var value: Variant

func _set(property: StringName, value_in: Variant) -> bool:
	if property == "property_preset":
		property_preset = value_in
		if property_preset != "":
			property_name = property_preset
		return true
	return false
