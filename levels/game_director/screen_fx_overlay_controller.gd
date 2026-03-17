extends RefCounted

func process_frame(host, delta: float) -> void:
	update_overlay_layer(host)
	if host._death_sequence_active:
		return
	if host._distortion_rect == null or host._distortion_material == null:
		return
	if not is_distortion_allowed(host):
		hide_distortion_overlays(host)
		return
	var has_active = false
	if host._distortion_active:
		host._distortion_rect.visible = true
		advance_distortion(host, delta)
		has_active = true
	if host._transition_active:
		host._transition_rect.visible = true
		advance_transition(host, delta)
		has_active = true
	if host._damage_flash_active:
		has_active = true
	if host._light_only_jump_active:
		has_active = true
	if host._flash_active:
		return
	if not has_active:
		hide_distortion_overlays(host)

func create_distortion_overlay(host) -> void:
	host._overlay_layer = CanvasLayer.new()
	host._overlay_layer.layer = 90
	host.add_child(host._overlay_layer)

	host._distortion_rect = ColorRect.new()
	host._distortion_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	host._distortion_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._distortion_rect.visible = false
	host._distortion_material = ShaderMaterial.new()
	host._distortion_material.shader = preload("res://shaders/distortion_overlay.gdshader")
	host._distortion_rect.material = host._distortion_material
	host._overlay_layer.add_child(host._distortion_rect)
	host._set_distortion_intensity(0.0)
	host._set_distortion_squash(0.0)

	host._transition_rect = ColorRect.new()
	host._transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	host._transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._transition_rect.visible = false
	host._transition_material = ShaderMaterial.new()
	host._transition_material.shader = preload("res://shaders/distortion_transition.gdshader")
	host._transition_rect.material = host._transition_material
	host._overlay_layer.add_child(host._transition_rect)
	host._set_transition_intensity(0.0)
	host._set_transition_squash(0.0)

	host._damage_rect = ColorRect.new()
	host._damage_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	host._damage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._damage_rect.visible = false
	host._damage_material = ShaderMaterial.new()
	host._damage_material.shader = preload("res://shaders/distortion_transition.gdshader")
	host._damage_rect.material = host._damage_material
	host._overlay_layer.add_child(host._damage_rect)
	host._set_damage_intensity(0.0)
	configure_damage_material(host)

	host._light_only_jump_rect = ColorRect.new()
	host._light_only_jump_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	host._light_only_jump_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._light_only_jump_rect.visible = false
	host._light_only_jump_material = ShaderMaterial.new()
	host._light_only_jump_material.shader = host.LIGHT_ONLY_JUMP_SHADER
	host._light_only_jump_rect.material = host._light_only_jump_material
	host._overlay_layer.add_child(host._light_only_jump_rect)
	configure_light_only_jump_material(host)
	host._set_light_only_jump_intensity(0.0)

func flash_red(host) -> void:
	if host._distortion_rect.visible:
		return
	if not is_distortion_allowed(host):
		return
	host._flash_active = true
	host._distortion_rect.visible = true
	host._set_distortion_intensity(0.25)
	host._set_distortion_squash(0.0)
	host.get_tree().create_timer(0.1).timeout.connect(func():
		if CycleState == null or CycleState.phase == CycleState.Phase.NORMAL:
			host._distortion_rect.visible = false
			host._set_distortion_intensity(0.0)
			host._set_distortion_squash(0.0)
		host._flash_active = false
	)

func flash_damage(host) -> void:
	if host._damage_rect == null or host._damage_material == null:
		return
	if host._death_sequence_active:
		return
	if host._damage_flash_active:
		return
	if not is_distortion_allowed(host):
		return
	host._damage_flash_active = true
	configure_damage_material(host)
	host._damage_rect.visible = true
	host._set_damage_intensity(host.damage_flash_intensity)
	apply_damage_camera_punch(host)
	host.get_tree().create_timer(host.damage_flash_duration).timeout.connect(func():
		if host._damage_rect:
			host._damage_rect.visible = false
			host._set_damage_intensity(0.0)
		host._damage_flash_active = false
	)

func configure_light_only_jump_material(host) -> void:
	if host._light_only_jump_material == null:
		return
	host._light_only_jump_material.set_shader_parameter("noise_speed", host.light_only_jump_noise_speed)
	host._light_only_jump_material.set_shader_parameter("glitch_amount", host.light_only_jump_glitch_amount)

func trigger_light_only_jump_effect(host, peak_intensity: float = -1.0) -> void:
	if not host.light_only_jump_effect_enabled:
		return
	if host._light_only_jump_rect == null or host._light_only_jump_material == null:
		return
	if host._death_sequence_active:
		return
	configure_light_only_jump_material(host)
	var target_peak = host.light_only_jump_peak_intensity if peak_intensity < 0.0 else peak_intensity
	target_peak = clampf(target_peak, 0.0, 1.0)
	var attack_time = maxf(0.01, host.light_only_jump_attack_duration)
	var release_time = maxf(0.01, host.light_only_jump_release_duration)
	var current = host._get_light_only_jump_intensity()
	var peak = maxf(current, target_peak)
	host._light_only_jump_rect.visible = true
	host._light_only_jump_active = true
	if host._light_only_jump_tween != null and is_instance_valid(host._light_only_jump_tween):
		host._light_only_jump_tween.kill()
	host._light_only_jump_tween = host.create_tween()
	host._light_only_jump_tween.tween_property(host._light_only_jump_material, "shader_parameter/intensity", peak, attack_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	host._light_only_jump_tween.tween_property(host._light_only_jump_material, "shader_parameter/intensity", 0.0, release_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	host._light_only_jump_tween.finished.connect(host._on_light_only_jump_effect_finished)

func on_light_only_jump_effect_finished(host) -> void:
	host._light_only_jump_tween = null
	host._light_only_jump_active = false
	if host._light_only_jump_rect:
		host._light_only_jump_rect.visible = false
	host._set_light_only_jump_intensity(0.0)

func stop_light_only_jump_effect(host) -> void:
	if host._light_only_jump_tween != null and is_instance_valid(host._light_only_jump_tween):
		host._light_only_jump_tween.kill()
	host._light_only_jump_tween = null
	host._light_only_jump_active = false
	if host._light_only_jump_rect:
		host._light_only_jump_rect.visible = false
	host._set_light_only_jump_intensity(0.0)

func configure_damage_material(host) -> void:
	if host._damage_material == null:
		return
	host._damage_material.set_shader_parameter("desaturation", host.damage_flash_desaturation)
	host._damage_material.set_shader_parameter("shake_power", host.damage_flash_shake_power)
	host._damage_material.set_shader_parameter("color_bleeding", host.damage_flash_color_bleeding)
	host._damage_material.set_shader_parameter("glitch_lines", host.damage_flash_glitch_lines)
	host._damage_material.set_shader_parameter("vignette_intensity", host.damage_flash_vignette_intensity)

func apply_damage_camera_punch(host) -> void:
	if host.damage_flash_duration <= 0.0:
		return
	var camera = resolve_primary_camera(host)
	if camera == null:
		return
	var base_zoom = camera.zoom
	var base_offset = camera.offset
	var base_rotation = camera.rotation
	var target_zoom = base_zoom * (1.0 + host.damage_flash_camera_zoom_punch)
	var jitter = Vector2(
		randf_range(-host.damage_flash_camera_offset_jitter, host.damage_flash_camera_offset_jitter),
		randf_range(-host.damage_flash_camera_offset_jitter, host.damage_flash_camera_offset_jitter)
	)
	var tilt_sign = -1.0 if randf() < 0.5 else 1.0
	var target_rotation = base_rotation + deg_to_rad(host.damage_flash_camera_tilt_deg) * tilt_sign
	var in_time: float = maxf(0.02, host.damage_flash_duration * 0.3)
	var out_time: float = maxf(0.02, host.damage_flash_duration * 0.7)
	var tween = host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "zoom", target_zoom, in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "offset", base_offset + jitter, in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "rotation", target_rotation, in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(camera, "zoom", base_zoom, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(camera, "offset", base_offset, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(camera, "rotation", base_rotation, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func resolve_primary_camera(host) -> Camera2D:
	if host.get_viewport() and host.get_viewport().get_camera_2d():
		return host.get_viewport().get_camera_2d()
	var player = host.get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	if player.has_node("Camera2D"):
		return player.get_node("Camera2D") as Camera2D
	return null

func apply_distortion_progress(host, progress: float) -> void:
	var value: float = float(clamp(progress, 0.0, 1.0))
	host._set_distortion_intensity(value)
	host._set_distortion_squash(value * host.distortion_squash_amount)

func apply_transition_strength(host, strength: float) -> void:
	var value: float = float(clamp(strength, 0.0, 1.0))
	host._set_transition_intensity(value * host.distortion_transition_intensity)

func advance_distortion(host, delta: float) -> void:
	if host.distortion_ramp_duration <= 0.0:
		host._distortion_progress = 1.0
	elif host._distortion_progress < 1.0:
		host._distortion_progress = min(1.0, host._distortion_progress + (delta / host.distortion_ramp_duration))
	var eased = ease_out(host._distortion_progress)
	apply_distortion_progress(host, eased)

func advance_transition(host, delta: float) -> void:
	if host.distortion_transition_duration <= 0.0:
		host._transition_progress = 1.0
	elif host._transition_progress < 1.0:
		host._transition_progress = min(1.0, host._transition_progress + (delta / host.distortion_transition_duration))
	var t: float = float(clamp(host._transition_progress, 0.0, 1.0))
	var strength = pow(1.0 - t, 2.0)
	apply_transition_strength(host, strength)
	if host._transition_progress >= 1.0:
		host._transition_active = false
		if host._transition_rect:
			host._transition_rect.visible = false

func ease_out(t: float) -> float:
	var clamped: float = float(clamp(t, 0.0, 1.0))
	return 1.0 - pow(1.0 - clamped, 2.0)

func is_distortion_allowed(host) -> bool:
	if not host._in_game_scene:
		return false
	if host._minigame_active and host._minigame_blocks_distortion:
		return false
	return true

func update_overlay_layer(host) -> void:
	if host._overlay_layer == null:
		return
	var target_layer = 90
	var pause_menu_open = false
	if PauseManager:
		pause_menu_open = PauseManager.is_pause_menu_open()
	if pause_menu_open or (host.get_tree() and host.get_tree().paused and not host._minigame_active):
		target_layer = 70
	elif host._minigame_active and MinigameController:
		target_layer = clampi(MinigameController.get_active_minigame_layer() - 1, 0, 89)
	if host._overlay_layer.layer != target_layer:
		host._overlay_layer.layer = target_layer

func hide_distortion_overlays(host) -> void:
	if host._distortion_rect:
		host._distortion_rect.visible = false
	if host._transition_rect:
		host._transition_rect.visible = false
	if host._damage_rect and not host._damage_flash_active:
		host._damage_rect.visible = false
	if host._light_only_jump_rect and not host._light_only_jump_active:
		host._light_only_jump_rect.visible = false
	host._set_distortion_intensity(0.0)
	host._set_distortion_squash(0.0)
	host._set_transition_intensity(0.0)
	host._set_transition_squash(0.0)
	if not host._damage_flash_active:
		host._set_damage_intensity(0.0)
	if not host._light_only_jump_active:
		host._set_light_only_jump_intensity(0.0)
