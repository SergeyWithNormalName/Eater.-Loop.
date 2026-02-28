extends "res://objects/interactable/interactive_object.gd"

@export var money_system_path: NodePath
@export var reward_money: int = 40
@export_multiline var talk_message: String = "Student: vot chast deneg za pomoshch."
@export_multiline var reward_message: String = "Ty poluchil dengi."
@export_multiline var already_given_message: String = "Student: ya uzhe vse otdal."
@export_range(0.0, 5.0, 0.05) var fade_out_duration: float = 0.35
@export_range(0.0, 5.0, 0.05) var fade_in_duration: float = 0.35

var _reward_given: bool = false
var _is_reward_in_progress: bool = false

func _on_interact() -> void:
	if _reward_given:
		if already_given_message.strip_edges() != "":
			UIMessage.show_text(already_given_message)
		return
	if _is_reward_in_progress:
		return

	_is_reward_in_progress = true
	if talk_message.strip_edges() != "":
		UIMessage.show_text(talk_message)

	await _play_reward_sequence()
	_reward_given = true
	complete_interaction()
	set_prompts_enabled(false)
	_hide_prompt()
	_is_reward_in_progress = false

func _play_reward_sequence() -> void:
	if UIMessage and UIMessage.has_method("fade_out"):
		await UIMessage.fade_out(fade_out_duration)
	else:
		await get_tree().create_timer(max(0.0, fade_out_duration)).timeout

	var money_system := _resolve_money_system()
	if money_system and money_system.has_method("add_money"):
		money_system.call("add_money", reward_money, "Student reward")

	if reward_message.strip_edges() != "":
		UIMessage.show_text(reward_message)

	if UIMessage and UIMessage.has_method("fade_in"):
		await UIMessage.fade_in(fade_in_duration)
	else:
		await get_tree().create_timer(max(0.0, fade_in_duration)).timeout

func _resolve_money_system() -> Node:
	if money_system_path.is_empty():
		return get_node_or_null("../Level12MoneySystem")
	return get_node_or_null(money_system_path)
