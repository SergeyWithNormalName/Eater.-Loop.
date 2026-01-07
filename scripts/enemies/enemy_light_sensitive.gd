extends "res://scripts/enemies/enemy_flashlight_base.gd"

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _is_flashlight_hitting():
		queue_free()

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if _is_flashlight_hitting():
		queue_free()
		return
	super._on_hitbox_area_body_entered(body)
