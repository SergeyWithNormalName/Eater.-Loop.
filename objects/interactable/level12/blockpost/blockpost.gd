extends "res://objects/interactable/door/door.gd"

@export var money_system_path: NodePath
@export var required_money: int = 100
@export_multiline var not_enough_money_message: String = "Nuzhno 100 rublei dlya prokhoda."
@export_multiline var access_granted_message: String = "Prokhod otkryt."
@export var unlock_after_success: bool = true

var _has_access: bool = false

func _try_use_door() -> void:
	var player := get_interacting_player()
	if player == null:
		return

	if _has_access:
		_play_sound(sfx_open)
		_perform_transition()
		return

	var money_system := _resolve_money_system()
	if money_system == null:
		UIMessage.show_text("Money system is not configured.")
		_play_sound(sfx_locked)
		return

	if not money_system.has_method("try_open_blockpost"):
		UIMessage.show_text("Money system API mismatch.")
		_play_sound(sfx_locked)
		return

	var can_pass := bool(money_system.call("try_open_blockpost", required_money))
	if not can_pass:
		if not_enough_money_message.strip_edges() != "":
			UIMessage.show_text(not_enough_money_message)
		_play_sound(sfx_locked)
		return

	if unlock_after_success:
		_has_access = true

	if access_granted_message.strip_edges() != "":
		UIMessage.show_text(access_granted_message)
	_play_sound(sfx_open)
	_perform_transition()

func _resolve_money_system() -> Node:
	if money_system_path.is_empty():
		return get_node_or_null("../Level12MoneySystem")
	return get_node_or_null(money_system_path)
