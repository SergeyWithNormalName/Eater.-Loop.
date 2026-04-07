extends RefCounted

const CycleLevelBaseScript = preload("res://levels/cycles/level.gd")

func start_normal_phase(host, timer_duration: float = -1.0) -> void:
	if CycleState != null:
		CycleState.set_phase(CycleState.Phase.NORMAL)
	host._pending_distortion_activation = false
	host._distortion_active = false
	host._distortion_progress = 0.0
	host._transition_active = false
	host._transition_progress = 0.0
	host._flash_active = false
	host._damage_flash_active = false
	host._stop_light_only_jump_effect()
	host._stalker_spawned = false
	host._hide_distortion_overlays()

	var time_to_set: float = timer_duration
	if time_to_set < 0.0:
		time_to_set = host.default_time

	if time_to_set > 0.0:
		host.current_max_time = time_to_set
		host._timer.start(time_to_set)
		print("GameDirector: Таймер запущен на %.1f сек." % time_to_set)
	else:
		host._timer.stop()
		host.current_max_time = 0.0
		print("GameDirector: Таймер отключен для уровня.")

func reduce_time(host, amount: float, damage_flash: bool = false) -> void:
	if amount <= 0.0:
		return
	if not is_timer_running(host):
		return
	set_time_left(host, get_time_left(host) - amount)
	if CycleState != null and CycleState.phase != CycleState.Phase.NORMAL:
		return
	if damage_flash:
		host.trigger_damage_flash()
	else:
		host._flash_red()

func trigger_damage_flash(host) -> void:
	if host._death_sequence_active:
		return
	host._flash_damage()

func on_distortion_timeout(host) -> void:
	if CycleState != null and CycleState.phase == CycleState.Phase.DISTORTED:
		host._pending_distortion_activation = false
		return
	if should_defer_distortion_activation(host):
		host._pending_distortion_activation = true
		return
	activate_distortion_phase(host)

func activate_distortion_phase(host) -> void:
	if CycleState != null and CycleState.phase == CycleState.Phase.DISTORTED:
		host._pending_distortion_activation = false
		return
	host._pending_distortion_activation = false
	if CycleState != null:
		CycleState.set_phase(CycleState.Phase.DISTORTED)
	host._distortion_active = true
	host._distortion_progress = 0.0
	host._transition_active = true
	host._transition_progress = 0.0
	host._flash_active = false
	host._damage_flash_active = false
	if host._damage_rect:
		host._damage_rect.visible = false
	host._set_damage_intensity(0.0)
	host._distortion_rect.visible = host._is_distortion_allowed()
	host._transition_rect.visible = host._is_distortion_allowed()
	host._apply_distortion_progress(0.0)
	host._apply_transition_strength(1.0)
	spawn_stalker_if_needed(host)
	host.distortion_started.emit()

func should_defer_distortion_activation(host) -> bool:
	if host._death_sequence_active:
		return false
	return host._minigame_active and host._minigame_blocks_distortion

func get_time_ratio(host) -> float:
	if CycleState != null and CycleState.phase != CycleState.Phase.NORMAL:
		return 0.0
	if host._timer.is_stopped() or host.current_max_time <= 0.0:
		return 1.0
	return host._timer.time_left / host.current_max_time

func get_time_left(host) -> float:
	if host.current_max_time <= 0.0:
		return 0.0
	if host._timer.is_stopped():
		if CycleState != null and CycleState.phase == CycleState.Phase.NORMAL:
			return host.current_max_time
		return 0.0
	return host._timer.time_left

func is_timer_running(host) -> bool:
	if CycleState != null and CycleState.phase != CycleState.Phase.NORMAL:
		return false
	return host.current_max_time > 0.0 and not host._timer.is_stopped()

func ensure_timer_running(host, fallback_time: float) -> void:
	if fallback_time <= 0.0:
		return
	if CycleState != null and CycleState.phase != CycleState.Phase.NORMAL:
		return
	if is_timer_running(host):
		return
	host.current_max_time = fallback_time
	host._timer.start(fallback_time)

func set_time_left(host, new_time: float) -> void:
	if host._death_sequence_active:
		return
	if CycleState != null and CycleState.phase != CycleState.Phase.NORMAL:
		return
	if host.current_max_time <= 0.0:
		return
	var clamped_time: float = float(clamp(new_time, 0.0, host.current_max_time))
	if clamped_time <= 0.0:
		host._timer.stop()
		on_distortion_timeout(host)
		return
	host._timer.start(clamped_time)

func apply_level_settings(host, scene: Node) -> void:
	host._current_cycle_number = resolve_cycle_number(host, scene)
	host._current_timer_duration = resolve_timer_duration(host, scene)
	start_normal_phase(host, host._current_timer_duration)

func resolve_cycle_number(host, scene: Node) -> int:
	if scene == null:
		return 0
	if scene is CycleLevelBaseScript:
		return int(scene.get_cycle_number())
	return 0

func resolve_timer_duration(host, scene: Node) -> float:
	if scene == null:
		return host.default_time
	if scene is CycleLevelBaseScript:
		return float(scene.get_timer_duration())
	return host.default_time

func spawn_stalker_if_needed(host) -> void:
	if host._stalker_spawned:
		return
	if not host._in_game_scene:
		return
	if host.stalker_scene == null:
		return
	var scene = host.get_tree().current_scene
	if scene == null:
		return
	var spawn = find_stalker_spawn(host, scene)
	if spawn == null:
		return
	host._stalker_spawned = true
	host.call_deferred("_spawn_stalker_deferred", scene, spawn.global_position)

func spawn_stalker_deferred(host, scene: Node, spawn_position: Vector2) -> void:
	if not host._stalker_spawned:
		return
	if scene == null or not is_instance_valid(scene):
		host._stalker_spawned = false
		return
	if host.get_tree() == null or scene != host.get_tree().current_scene:
		host._stalker_spawned = false
		return
	var stalker = host.stalker_scene.instantiate()
	if stalker == null:
		host._stalker_spawned = false
		return
	scene.add_child(stalker)
	if stalker is Node2D:
		(stalker as Node2D).global_position = spawn_position

func find_stalker_spawn(host, scene: Node) -> Node2D:
	var nodes = host.get_tree().get_nodes_in_group(host.STALKER_SPAWN_GROUP)
	for node in nodes:
		if node is Node2D and scene.is_ancestor_of(node):
			return node
	return null

func on_minigame_started(host, minigame: Node) -> void:
	host._minigame_active = true
	host._minigame_blocks_distortion = not minigame_allows_distortion(minigame)

func on_minigame_finished(host, _minigame: Node, _success: bool) -> void:
	host._minigame_active = false
	host._minigame_blocks_distortion = false
	if host._pending_distortion_activation:
		activate_distortion_phase(host)

func minigame_allows_distortion(minigame: Node) -> bool:
	if minigame == null:
		return true
	if minigame.has_method("allows_distortion_overlay"):
		return bool(minigame.allows_distortion_overlay())
	if minigame.has_meta("allow_distortion_overlay"):
		return bool(minigame.get_meta("allow_distortion_overlay"))
	return true
