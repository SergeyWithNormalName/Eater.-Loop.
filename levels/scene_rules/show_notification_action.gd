extends "res://levels/scene_rules/scene_rule_action.gd"
class_name ShowNotificationAction

@export_multiline var message: String = ""

func execute(_runner, _args: Array = []) -> void:
	if message.strip_edges() == "":
		return
	if UIMessage != null:
		UIMessage.show_notification(message)
