extends "res://objects/interactable/door/door.gd"

@export var money_system_path: NodePath
@export var required_money: int = 100
@export_multiline var not_enough_money_message: String = "Нужно 100 рублей для прохода."
@export_multiline var access_granted_message: String = "Проход открыт."
@export var unlock_after_success: bool = true
@export_range(0.0, 5.0, 0.1) var touch_warning_cooldown: float = 1.0

var _has_access: bool = false
var _last_touch_warning_time: float = -1000.0

@onready var _touch_area: Area2D = get_node_or_null("TouchArea") as Area2D
@onready var _passage_block_shape: CollisionShape2D = get_node_or_null("PassageBlocker/CollisionShape2D") as CollisionShape2D

func _ready() -> void:
	super._ready()
	_set_passage_block_enabled(not _has_access)
	if _touch_area != null and not _touch_area.body_entered.is_connected(_on_touch_area_body_entered):
		_touch_area.body_entered.connect(_on_touch_area_body_entered)

func _on_touch_area_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if _has_access:
		return
	if _can_afford_passage():
		return
	_show_not_enough_money_feedback(false)

func _try_use_door() -> void:
	var player := get_interacting_player()
	if player == null:
		return

	if _has_access:
		return

	var money_system := _resolve_money_system()
	if money_system == null:
		UIMessage.show_notification("Система денег не настроена.")
		_play_sound(sfx_locked)
		return

	var can_pass: bool = money_system.try_open_blockpost(required_money)
	if not can_pass:
		_show_not_enough_money_feedback(true)
		return

	if unlock_after_success:
		_has_access = true
		_set_passage_block_enabled(false)

	if access_granted_message.strip_edges() != "":
		UIMessage.show_notification(access_granted_message)
	_play_sound(sfx_open)

func _resolve_money_system() -> Level12MoneySystem:
	if money_system_path.is_empty():
		return get_node_or_null("../Level12MoneySystem") as Level12MoneySystem
	return get_node_or_null(money_system_path) as Level12MoneySystem

func _can_afford_passage() -> bool:
	var money_system := _resolve_money_system()
	if money_system == null:
		return false
	return money_system.has_enough_money(required_money)

func _show_not_enough_money_feedback(force: bool) -> void:
	if not force:
		var now: float = float(Time.get_ticks_msec()) / 1000.0
		if now - _last_touch_warning_time < maxf(0.0, touch_warning_cooldown):
			return
		_last_touch_warning_time = now

	if not_enough_money_message.strip_edges() != "":
		UIMessage.show_notification(not_enough_money_message)
	_play_sound(sfx_locked)

func _set_passage_block_enabled(enabled: bool) -> void:
	if _passage_block_shape == null:
		return
	_passage_block_shape.disabled = not enabled
