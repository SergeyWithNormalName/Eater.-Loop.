extends "res://objects/interactable/notebook/laptop.gd"

@export var money_system_path: NodePath
@export var reward_money: int = 60
@export_multiline var reward_reason: String = "Lab reward"

var _money_rewarded: bool = false
var _lab_completed_before_minigame: bool = false

func _start_lab_minigame() -> void:
	_lab_completed_before_minigame = _is_lab_completed()
	super._start_lab_minigame()

func _on_minigame_closed() -> void:
	var was_completed_before := _lab_completed_before_minigame
	super._on_minigame_closed()
	if _money_rewarded:
		return
	if was_completed_before:
		return
	if not _is_lab_completed():
		return

	var money_system := _resolve_money_system()
	if money_system == null or not money_system.has_method("add_money"):
		return
	money_system.call("add_money", reward_money, reward_reason)
	_money_rewarded = true

func _resolve_money_system() -> Node:
	if money_system_path.is_empty():
		return get_node_or_null("../Level12MoneySystem")
	return get_node_or_null(money_system_path)
