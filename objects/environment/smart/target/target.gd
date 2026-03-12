extends Marker2D
class_name TargetMonsterSpawner

signal enemy_spawned(enemy: Node)

enum ConditionType {
	GAMESTATE_BOOL,
	NODE_SIGNAL,
	TRIGGER_ENTER
}

@export_group("Spawn")
## Какого монстра спавнить.
@export var enemy_scene: PackedScene
## Куда добавить инстанс монстра (пусто = текущая сцена).
@export var spawn_parent_path: NodePath
## Доп. смещение спавна относительно target.
@export var spawn_offset: Vector2 = Vector2.ZERO
## Передать монстру поворот target.
@export var inherit_target_rotation: bool = false
## Если true, спавнит монстра только один раз.
@export var one_shot: bool = true
## Удалить target после успешного спавна.
@export var auto_free_after_spawn: bool = false

@export_group("Condition")
## Тип условия, после которого будет спавн.
@export_enum("Флаг GameState", "Сигнал от узла", "Вход в триггер") var condition_type: int = ConditionType.GAMESTATE_BOOL

@export_group("Condition/GameState")
## Имя bool-поля в CycleState или GameState.
@export_enum("ate_this_cycle", "lab_done", "phone_picked", "fridge_interacted", "unique_feeding_intro_played", "electricity_on") var game_state_flag_name: String = "ate_this_cycle"
## Ожидаемое значение флага.
@export var game_state_expected_value: bool = true
## Проверять флаг каждый кадр, если нет подходящего сигнала.
@export var poll_game_state_when_no_signal: bool = true

@export_group("Condition/Node Signal")
## Узел, от сигнала которого ждать условие (например, интерактивный объект).
@export var condition_node_path: NodePath
## Имя сигнала у узла (например, interaction_finished).
@export var condition_signal_name: StringName = &"interaction_finished"
## Необязательная проверка bool-свойства узла на момент сигнала.
@export var condition_property_name: StringName = &""
## Ожидаемое значение bool-свойства condition_property_name.
@export var condition_property_expected_value: bool = true

@export_group("Condition/Trigger")
## Area2D-триггер, вход в который активирует спавн.
@export var trigger_area_path: NodePath
## Какая группа считается игроком.
@export var trigger_player_group: String = "player"
## Срабатывать по выходу из триггера вместо входа.
@export var trigger_on_exit: bool = false
## При старте проверить, не стоит ли игрок уже в триггере.
@export var check_overlapping_on_ready: bool = true

const OVERLAP_CHECK_ATTEMPTS := 6

var _spawned: bool = false

func _ready() -> void:
	add_to_group("target_monster_spawner")
	if not is_in_group("checkpoint_stateful"):
		add_to_group("checkpoint_stateful")
	_arm_condition()

func _process(_delta: float) -> void:
	if condition_type != ConditionType.GAMESTATE_BOOL:
		set_process(false)
		return
	if _spawned and one_shot:
		set_process(false)
		return
	if _is_game_state_condition_met():
		_spawn_enemy()
		set_process(false)

func _arm_condition() -> void:
	match condition_type:
		ConditionType.GAMESTATE_BOOL:
			_arm_game_state_condition()
		ConditionType.NODE_SIGNAL:
			_arm_node_signal_condition()
		ConditionType.TRIGGER_ENTER:
			_arm_trigger_condition()
		_:
			push_warning("TargetMonsterSpawner: неизвестный condition_type: %s" % [condition_type])

func _arm_game_state_condition() -> void:
	if _is_game_state_condition_met():
		_spawn_enemy()
		return
	var connected := _connect_game_state_signal_if_possible()
	if not connected and poll_game_state_when_no_signal:
		set_process(true)

func _connect_game_state_signal_if_possible() -> bool:
	var state_owner := _resolve_state_owner()
	if state_owner == null:
		return false
	var signal_name := StringName()
	match game_state_flag_name:
		"lab_done":
			signal_name = &"lab_completed"
		"phone_picked":
			signal_name = &"phone_picked_changed"
		"fridge_interacted":
			signal_name = &"fridge_interacted_changed"
		"electricity_on":
			signal_name = &"electricity_changed"
		_:
			return false
	if not state_owner.has_signal(signal_name):
		return false
	var callback := Callable(self, "_on_game_state_signal")
	if not state_owner.is_connected(signal_name, callback):
		state_owner.connect(signal_name, callback)
	return true

func _is_game_state_condition_met() -> bool:
	var state_owner := _resolve_state_owner()
	if state_owner == null:
		return false
	if not _has_property(state_owner, game_state_flag_name):
		push_warning("TargetMonsterSpawner: в GameState нет свойства '%s'." % game_state_flag_name)
		return false
	return bool(state_owner.get(game_state_flag_name)) == game_state_expected_value

func _resolve_state_owner() -> Object:
	match game_state_flag_name:
		"unique_feeding_intro_played":
			return GameState
		_:
			return CycleState

func _on_game_state_signal(_arg0: Variant = null) -> void:
	if _spawned and one_shot:
		return
	if _is_game_state_condition_met():
		_spawn_enemy()

func _arm_node_signal_condition() -> void:
	var source := get_node_or_null(condition_node_path)
	if source == null:
		push_warning("TargetMonsterSpawner: не найден condition_node_path.")
		return
	if _is_node_property_condition_met(source):
		_spawn_enemy()
		return
	if condition_signal_name == StringName():
		push_warning("TargetMonsterSpawner: пустой condition_signal_name.")
		return
	if not source.has_signal(condition_signal_name):
		push_warning("TargetMonsterSpawner: у узла нет сигнала '%s'." % String(condition_signal_name))
		return
	var callback := Callable(self, "_on_condition_node_signal")
	if not source.is_connected(condition_signal_name, callback):
		source.connect(condition_signal_name, callback)

func _is_node_property_condition_met(source: Node) -> bool:
	if source == null:
		return false
	if condition_property_name == StringName():
		return false
	var prop_name := String(condition_property_name)
	if not _has_property(source, prop_name):
		return false
	return bool(source.get(prop_name)) == condition_property_expected_value

func _on_condition_node_signal(
	_arg0: Variant = null,
	_arg1: Variant = null,
	_arg2: Variant = null,
	_arg3: Variant = null
) -> void:
	if _spawned and one_shot:
		return
	var source := get_node_or_null(condition_node_path)
	if condition_property_name != StringName() and not _is_node_property_condition_met(source):
		return
	_spawn_enemy()

func _arm_trigger_condition() -> void:
	var trigger := get_node_or_null(trigger_area_path) as Area2D
	if trigger == null:
		push_warning("TargetMonsterSpawner: trigger_area_path должен указывать на Area2D.")
		return
	if trigger_on_exit:
		if not trigger.body_exited.is_connected(_on_trigger_body_exited):
			trigger.body_exited.connect(_on_trigger_body_exited)
	else:
		if not trigger.body_entered.is_connected(_on_trigger_body_entered):
			trigger.body_entered.connect(_on_trigger_body_entered)
		if check_overlapping_on_ready:
			call_deferred("_check_trigger_overlap", trigger)

func _on_trigger_body_entered(body: Node) -> void:
	if _spawned and one_shot:
		return
	if body == null or not body.is_in_group(trigger_player_group):
		return
	_spawn_enemy()

func _on_trigger_body_exited(body: Node) -> void:
	if _spawned and one_shot:
		return
	if body == null or not body.is_in_group(trigger_player_group):
		return
	_spawn_enemy()

func _check_trigger_overlap(trigger: Area2D) -> void:
	for _attempt in range(OVERLAP_CHECK_ATTEMPTS):
		if trigger == null or not is_instance_valid(trigger):
			return
		for body in trigger.get_overlapping_bodies():
			if body != null and body.is_in_group(trigger_player_group):
				_spawn_enemy()
				return
		await get_tree().physics_frame

func _spawn_enemy() -> Node:
	if _spawned and one_shot:
		return null
	if enemy_scene == null:
		push_warning("TargetMonsterSpawner: не назначен enemy_scene.")
		return null
	var parent := _resolve_spawn_parent()
	if parent == null:
		push_warning("TargetMonsterSpawner: не найден parent для спавна.")
		return null
	var enemy := enemy_scene.instantiate()
	if enemy == null:
		push_warning("TargetMonsterSpawner: не удалось инстанцировать enemy_scene.")
		return null
	parent.add_child(enemy)
	_place_spawned_enemy(enemy)
	_spawned = true
	set_process(false)
	enemy_spawned.emit(enemy)
	if auto_free_after_spawn:
		queue_free()
	return enemy

func capture_checkpoint_state() -> Dictionary:
	return {
		"spawned": _spawned,
	}

func apply_checkpoint_state(state: Dictionary) -> void:
	_spawned = bool(state.get("spawned", _spawned))
	if _spawned and one_shot:
		set_process(false)

func _place_spawned_enemy(enemy: Node) -> void:
	if not (enemy is Node2D):
		return
	var enemy_2d := enemy as Node2D
	enemy_2d.global_position = global_position + spawn_offset
	if inherit_target_rotation:
		enemy_2d.global_rotation = global_rotation

func _resolve_spawn_parent() -> Node:
	if not spawn_parent_path.is_empty():
		var explicit_parent := get_node_or_null(spawn_parent_path)
		if explicit_parent != null:
			return explicit_parent
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	return get_parent()

func _has_property(node: Node, prop_name: String) -> bool:
	for info in node.get_property_list():
		if String(info.name) == prop_name:
			return true
	return false
