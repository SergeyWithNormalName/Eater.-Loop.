extends Area2D
class_name FridgeInteract

@export var freeze_player_name: String = "Player"

var player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.name == freeze_player_name:
		player_inside = true


func _on_body_exited(body: Node) -> void:
	if body.name == freeze_player_name:
		player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not player_inside:
		return

	if event.is_action_pressed("interact"):
		_feed_andrey()


func _feed_andrey() -> void:
	# если уже поел в этом цикле — ничего не делаем
	if GameState.ate_this_cycle:
		ui_message.show_text("Ты уже ел.")
		return

	GameState.mark_ate()
	ui_message.show_text("Андрей поел")
