extends Resource
class_name LaptopRewardConfig

@export var enabled: bool = false
@export var money_system_path: NodePath
@export var reward_money: int = 60
@export_multiline var reward_reason: String = "Награда за лабораторную"
@export var reward_once: bool = true
