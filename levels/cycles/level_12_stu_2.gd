extends "res://levels/cycles/level.gd"

func _ready() -> void:
	super._ready()
	call_deferred("_wire_level12_dependencies")

func _wire_level12_dependencies() -> void:
	var generator := get_node_or_null("Generator")
	var fridge := get_node_or_null("6thLevel/604/InteractableObjects/Fridge")
	if generator == null or fridge == null:
		return

	fridge.set("dependency_object", generator)
	fridge.set("locked_message", "Snachala zapusti generator.")

	if fridge.has_method("_setup_dependency_listener"):
		fridge.call("_setup_dependency_listener")
	if fridge.has_method("_refresh_prompt_state"):
		fridge.call("_refresh_prompt_state")
