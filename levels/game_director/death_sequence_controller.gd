extends RefCounted

const CycleLevelBaseScript = preload("res://levels/cycles/level.gd")

func create_death_overlay(host) -> void:
	host._death_layer = CanvasLayer.new()
	host._death_layer.layer = 120
	host._death_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	host.add_child(host._death_layer)

	host._death_fade_rect = ColorRect.new()
	host._death_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	host._death_fade_rect.color = Color(0, 0, 0, 0)
	host._death_fade_rect.visible = false
	host._death_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	host._death_fade_rect.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	host._death_layer.add_child(host._death_fade_rect)

	host._death_root = Control.new()
	host._death_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	host._death_root.visible = false
	host._death_root.mouse_filter = Control.MOUSE_FILTER_STOP
	host._death_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	host._death_layer.add_child(host._death_root)

	host._death_glitch_background = Control.new()
	host._death_glitch_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	host._death_glitch_background.visible = false
	host._death_glitch_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._death_glitch_background.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	host._death_root.add_child(host._death_glitch_background)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._death_root.add_child(center)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(content)

	host._death_title_label = Label.new()
	host._death_title_label.text = host.death_title_text
	host._death_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._death_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host._death_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._death_title_label.add_theme_font_size_override("font_size", 112)
	var base_font = load("res://global/fonts/AmaticSC-Regular.ttf")
	if base_font:
		var font_variation = FontVariation.new()
		font_variation.base_font = base_font
		font_variation.spacing_glyph = 3
		host._death_title_label.add_theme_font_override("font", font_variation)
	content.add_child(host._death_title_label)
	host._death_title_glitch_material = build_death_glitch_material(host, 0.82, 0.06, 0.016, 0.3, 11.0, Color(1.0, 0.82, 0.82, 1.0))
	host._death_title_readable_glitch_material = build_death_glitch_material(host, 0.38, 0.028, 0.008, 0.12, 6.5, Color(1.0, 0.9, 0.9, 1.0))
	apply_death_title(host, host.death_title_text, false)

	host._death_retry_button = Button.new()
	host._death_retry_button.text = host.death_retry_text
	host._death_retry_button.custom_minimum_size = Vector2(420, 92)
	host._death_retry_button.focus_mode = Control.FOCUS_ALL
	host._death_retry_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	host._death_retry_button.pressed.connect(host._on_death_retry_pressed)
	content.add_child(host._death_retry_button)
	host._death_focus_style_hidden = StyleBoxEmpty.new()

func trigger_death_screen(host) -> void:
	if host._death_sequence_active:
		return
	if handle_custom_scene_death(host):
		return
	host._death_sequence_active = true
	release_death_cursor_request(host)
	host._timer.stop()
	host._distortion_active = false
	host._distortion_progress = 0.0
	host._transition_active = false
	host._transition_progress = 0.0
	host._flash_active = false
	host._damage_flash_active = false
	host._stop_light_only_jump_effect()
	host._hide_distortion_overlays()
	host._death_camera = host._resolve_primary_camera()
	if host._death_camera != null:
		host._death_camera_base_rotation = host._death_camera.rotation
		host._death_camera_base_zoom = host._death_camera.zoom
		host._death_camera_base_offset = host._death_camera.offset
	apply_next_death_title(host)
	if host._death_retry_button:
		host._death_retry_button.text = host.death_retry_text
	if host._death_root:
		host._death_root.visible = false
	if host._death_fade_rect:
		host._death_fade_rect.visible = true
		host._death_fade_rect.color = Color(0, 0, 0, 0)
	var fade_time: float = maxf(0.01, host.death_fade_duration)
	var tween = host.create_tween()
	tween.set_parallel(true)
	if host._death_fade_rect:
		tween.tween_property(host._death_fade_rect, "color:a", 1.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if host._death_camera != null:
		var tilt_sign = -1.0 if randf() < 0.5 else 1.0
		var target_rotation = host._death_camera_base_rotation + deg_to_rad(host.death_camera_tilt_deg) * tilt_sign
		var target_zoom = host._death_camera_base_zoom * host.death_camera_zoom_mult
		tween.tween_property(host._death_camera, "rotation", target_rotation, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(host._death_camera, "zoom", target_zoom, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(host._on_death_fade_completed)

func handle_custom_scene_death(host) -> bool:
	var scene = host.get_tree().current_scene
	if scene == null:
		return false
	if not (scene is CycleLevelBaseScript):
		return false
	return bool(scene.handle_custom_death_screen())

func on_death_fade_completed(host) -> void:
	if not host._death_sequence_active:
		return
	if host._death_root:
		host._death_root.visible = true
	apply_death_input_mode(host)
	if host.get_tree():
		host.get_tree().paused = true

func on_death_retry_pressed(host) -> void:
	if not host._death_sequence_active:
		return
	var restored_autosave = false
	if GameState != null:
		restored_autosave = bool(GameState.restore_respawn_checkpoint())
		if not restored_autosave:
			restored_autosave = bool(GameState.restore_autosave_run())
	if not restored_autosave and CycleState != null:
		CycleState.reset_cycle_state()
	if CycleState != null:
		CycleState.queue_respawn_blackout()
	if UIMessage != null:
		UIMessage.set_screen_dark(true)
	restore_death_camera(host)
	if host._death_root:
		host._death_root.visible = false
	release_death_cursor_request(host)
	if host.get_tree():
		host.get_tree().paused = false
		host.get_tree().call_deferred("reload_current_scene")

func reset_death_screen_state(host) -> void:
	host._death_sequence_active = false
	restore_death_camera(host)
	if host._death_root:
		host._death_root.visible = false
	if host._death_glitch_background:
		host._death_glitch_background.visible = false
	if host._death_fade_rect:
		host._death_fade_rect.visible = false
		host._death_fade_rect.color = Color(0, 0, 0, 0)
	if host._death_retry_button:
		host._death_retry_button.remove_theme_stylebox_override("focus")
	release_death_cursor_request(host)
	if host.get_tree() and host.get_tree().paused:
		host.get_tree().paused = false

func restore_death_camera(host) -> void:
	if host._death_camera != null and is_instance_valid(host._death_camera):
		host._death_camera.rotation = host._death_camera_base_rotation
		host._death_camera.zoom = host._death_camera_base_zoom
		host._death_camera.offset = host._death_camera_base_offset
	host._death_camera = null

func apply_next_death_title(host) -> void:
	if host._death_title_sequence_index < host.DEATH_TITLE_SEQUENCE.size():
		var next_index = host._death_title_sequence_index
		host._death_title_sequence_index += 1
		var is_glitch_title = next_index == host.DEATH_TITLE_SEQUENCE.size() - 1
		apply_death_title(host, host.DEATH_TITLE_SEQUENCE[next_index], is_glitch_title)
		return
	apply_death_title(host, host.death_title_text, false)

func apply_death_title(host, text: String, glitchy: bool) -> void:
	if host._death_title_label == null:
		return
	update_death_title_layout(host, glitchy)
	host._death_title_label.text = get_readable_death_glitch_text(host, text) if glitchy else text
	host._death_title_label.rotation = 0.0
	host._death_title_label.scale = Vector2.ONE
	host._death_title_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	host._death_title_label.remove_theme_color_override("font_color")
	host._death_title_label.remove_theme_color_override("font_shadow_color")
	host._death_title_label.remove_theme_constant_override("shadow_offset_x")
	host._death_title_label.remove_theme_constant_override("shadow_offset_y")
	if glitchy:
		host._death_title_label.add_theme_font_size_override("font_size", 58)
		host._death_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.9, 1.0))
		host._death_title_label.add_theme_color_override("font_shadow_color", Color(0.32, 0.0, 0.0, 0.92))
		host._death_title_label.add_theme_constant_override("shadow_offset_x", 3)
		host._death_title_label.add_theme_constant_override("shadow_offset_y", 3)
		host._death_title_label.material = host._death_title_readable_glitch_material
		show_death_glitch_background(host, text)
	else:
		host._death_title_label.add_theme_font_size_override("font_size", 112)
		host._death_title_label.material = null
		if host._death_glitch_background:
			host._death_glitch_background.visible = false

func update_death_title_layout(host, glitchy: bool = false) -> void:
	if host._death_title_label == null:
		return
	var title_width = 1280.0
	if host.get_viewport():
		var visible_size = host.get_viewport().get_visible_rect().size
		var width_ratio = 0.92 if glitchy else 0.82
		var min_width = 860.0 if glitchy else 620.0
		title_width = maxf(min_width, visible_size.x * width_ratio)
	host._death_title_label.custom_minimum_size = Vector2(title_width, 0.0)

func get_readable_death_glitch_text(host, text: String) -> String:
	if text == host.DEATH_TITLE_PENANCE_TEXT:
		return "%s\n%s" % [host.DEATH_TITLE_PENANCE_LINE, host.DEATH_TITLE_PENANCE_LINE]
	return text

func build_death_glitch_material(host, glitch_strength: float, line_jitter: float, chroma_shift: float, scanline_strength: float, flicker_speed: float, tint: Color) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = host.DEATH_TITLE_GLITCH_SHADER
	material.set_shader_parameter("glitch_strength", glitch_strength)
	material.set_shader_parameter("line_jitter", line_jitter)
	material.set_shader_parameter("chroma_shift", chroma_shift)
	material.set_shader_parameter("scanline_strength", scanline_strength)
	material.set_shader_parameter("flicker_speed", flicker_speed)
	material.set_shader_parameter("tint", tint)
	return material

func show_death_glitch_background(host, text: String) -> void:
	if host._death_glitch_background == null:
		return
	var viewport_size = Vector2(1920.0, 1080.0)
	if host.get_viewport():
		viewport_size = host.get_viewport().get_visible_rect().size
	var background_text = build_death_glitch_background_text(host, text)
	for child in host._death_glitch_background.get_children():
		child.free()
	for layout_variant in host.DEATH_GLITCH_BACKGROUND_LAYOUT:
		if not (layout_variant is Dictionary):
			continue
		var layout = layout_variant as Dictionary
		var label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = background_text
		label.add_theme_font_size_override("font_size", int(layout.get("font_size", 64)))
		label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.86, float(layout.get("alpha", 0.18))))
		label.add_theme_color_override("font_shadow_color", Color(0.25, 0.0, 0.0, minf(0.95, float(layout.get("alpha", 0.18)) + 0.16)))
		label.add_theme_constant_override("shadow_offset_x", 3)
		label.add_theme_constant_override("shadow_offset_y", 3)
		label.rotation = float(layout.get("rotation", 0.0))
		var scale_value: Variant = layout.get("scale", Vector2.ONE)
		if scale_value is Vector2:
			label.scale = scale_value
		var anchor_value: Variant = layout.get("anchor", Vector2.ZERO)
		var offset_value: Variant = layout.get("offset", Vector2.ZERO)
		var anchor = Vector2.ZERO
		if anchor_value is Vector2:
			anchor = anchor_value
		var offset = Vector2.ZERO
		if offset_value is Vector2:
			offset = offset_value
		var width = float(layout.get("width", viewport_size.x * 0.45))
		label.position = Vector2(viewport_size.x * anchor.x, viewport_size.y * anchor.y) + offset
		label.custom_minimum_size = Vector2(width, 0.0)
		var alpha = float(layout.get("alpha", 0.18))
		var strength = float(layout.get("strength", 0.8))
		label.material = build_death_glitch_material(host, strength, 0.065, 0.018, 0.32, 12.0, Color(1.0, 0.8, 0.8, alpha))
		host._death_glitch_background.add_child(label)
	host._death_glitch_background.visible = true

func build_death_glitch_background_text(host, text: String) -> String:
	var compact = text.replace("\n", " ").strip_edges()
	if compact == "":
		compact = host.DEATH_TITLE_PENANCE_LINE
	if compact == host.DEATH_TITLE_PENANCE_TEXT:
		return host.DEATH_TITLE_PENANCE_TEXT
	return ("%s %s %s" % [compact, compact, compact]).strip_edges()

func apply_death_input_mode(host) -> void:
	var using_gamepad = host._input_kind == host.INPUT_KIND_GAMEPAD
	if host._death_retry_button:
		if using_gamepad:
			if host._death_focus_style_hidden == null:
				host._death_focus_style_hidden = StyleBoxEmpty.new()
			host._death_retry_button.add_theme_stylebox_override("focus", host._death_focus_style_hidden)
			host._death_retry_button.grab_focus()
		else:
			host._death_retry_button.remove_theme_stylebox_override("focus")
			if host._death_retry_button.has_focus():
				host._death_retry_button.release_focus()
	if CursorManager:
		if using_gamepad:
			CursorManager.release_visible(host)
		else:
			CursorManager.request_visible(host)

func release_death_cursor_request(host) -> void:
	if CursorManager:
		CursorManager.release_visible(host)

func resolve_input_kind(host, event: InputEvent) -> int:
	if event == null or event.is_echo():
		return host.INPUT_KIND_UNKNOWN
	if event is InputEventJoypadButton:
		var joy_button = event as InputEventJoypadButton
		if not joy_button.pressed:
			return host.INPUT_KIND_UNKNOWN
		return host.INPUT_KIND_GAMEPAD
	if event is InputEventJoypadMotion:
		var joy_motion = event as InputEventJoypadMotion
		if absf(joy_motion.axis_value) < host.JOYPAD_MOTION_DEADZONE:
			return host.INPUT_KIND_UNKNOWN
		return host.INPUT_KIND_GAMEPAD
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if not key_event.pressed:
			return host.INPUT_KIND_UNKNOWN
		return host.INPUT_KIND_KEYBOARD
	if event is InputEventMouseButton:
		var mouse_button = event as InputEventMouseButton
		if not mouse_button.pressed:
			return host.INPUT_KIND_UNKNOWN
		return host.INPUT_KIND_KEYBOARD
	if event is InputEventMouseMotion:
		var mouse_motion = event as InputEventMouseMotion
		if mouse_motion.relative.length_squared() <= 0.0:
			return host.INPUT_KIND_UNKNOWN
		return host.INPUT_KIND_KEYBOARD
	return host.INPUT_KIND_UNKNOWN
