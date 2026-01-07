extends "res://scripts/enemies/enemy_flashlight_base.gd"

func _physics_process(delta: float) -> void:
	if _is_flashlight_hitting():
		super._physics_process(delta)
	else:
		velocity = Vector2.ZERO
		move_and_slide()

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if not _is_flashlight_hitting():
		return
	super._on_hitbox_area_body_entered(body)
