extends RefCounted
class_name LaptopCompletionReward

var reward_on_work_completion: bool = false
var money_system_path: NodePath
var reward_money: int = 0
var reward_reason: String = ""
var reward_once: bool = true
var money_rewarded: bool = false

func configure(
	reward_on_work_completion_value: bool,
	money_system_path_value: NodePath,
	reward_money_value: int,
	reward_reason_value: String,
	reward_once_value: bool
) -> void:
	reward_on_work_completion = reward_on_work_completion_value
	money_system_path = money_system_path_value
	reward_money = reward_money_value
	reward_reason = reward_reason_value
	reward_once = reward_once_value

func try_reward(owner: Node) -> void:
	if not reward_on_work_completion:
		return
	if reward_once and money_rewarded:
		return
	if reward_money <= 0:
		return
	var money_system := resolve_money_system(owner)
	if money_system == null:
		return
	money_system.add_money(reward_money, reward_reason)
	money_rewarded = true

func resolve_money_system(owner: Node) -> Level12MoneySystem:
	if owner == null:
		return null
	if money_system_path.is_empty():
		return owner.get_node_or_null("../Level12MoneySystem") as Level12MoneySystem
	return owner.get_node_or_null(money_system_path) as Level12MoneySystem

func capture_state() -> Dictionary:
	return {
		"money_rewarded": money_rewarded,
	}

func apply_state(state: Dictionary) -> void:
	money_rewarded = bool(state.get("money_rewarded", money_rewarded))
