extends Area2D

# Убрал class_name, если он не используется в других скриптах для типизации, чтобы не засорять глобальное пространство.

var player_inside: bool = false

func _ready() -> void:
	# Отключаем возможность кликать мышкой, оставляем только Interact
	input_pickable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside:
		return

	if event.is_action_pressed("interact"):
		_feed_andrey()

func _feed_andrey() -> void:
	if GameState.ate_this_cycle:
		UIMessage.show_text("Ты уже ел.")
		return

	GameState.mark_ate()
	UIMessage.show_text("Андрей поел.")
