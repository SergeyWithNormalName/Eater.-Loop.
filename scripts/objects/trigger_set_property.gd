extends Area2D

@export_group("Trigger")
## Применять изменения при входе игрока.
@export var affect_on_enter: bool = true
## Применять изменения при выходе игрока.
@export var affect_on_exit: bool = false
## Срабатывает только один раз.
@export var one_shot: bool = true
## Группа, которую считает игроком.
@export var player_group: String = "player"

@export_group("Targets")
## Набор изменений через ресурсы PropertyChange (приоритетнее списков ниже).
@export var changes: Array[PropertyChange] = []
## Пути к целевым узлам для простого изменения свойства.
@export var target_paths: Array[NodePath] = []
## Имя свойства для простого изменения.
@export var property_name: String = ""
## Значение свойства для простого изменения.
@export var value: Variant

@export_group("Sound")
## Звук, который проигрывается при срабатывании.
@export var sfx_stream: AudioStream
## Позиция звука, если не использовать позицию триггера.
@export var sfx_position: Vector2 = Vector2.ZERO
## Использовать позицию триггера для звука.
@export var sfx_use_trigger_position: bool = false
## Задержка перед проигрыванием звука.
@export var sfx_delay: float = 0.0
## Громкость звука в дБ.
@export var sfx_volume_db: float = 0.0

@export_group("Музыка")
## Включить управление музыкой через триггер.
@export var music_enabled: bool = false
## Действие с музыкой при входе.
@export_enum("Не менять", "Подменить трек", "Заглушить", "Восстановить") var music_on_enter: int = 0
## Действие с музыкой при выходе.
@export_enum("Не менять", "Подменить трек", "Заглушить", "Восстановить") var music_on_exit: int = 0
## Музыка для подмены.
@export var music_stream: AudioStream
## Громкость музыки (дБ).
@export_range(-80.0, 6.0, 0.1) var music_volume_db: float = 0.0
## Длительность плавного перехода (сек).
@export_range(0.0, 10.0, 0.1) var music_fade_time: float = 1.0

var _has_fired: bool = false

const MUSIC_ACTION_NONE := 0
const MUSIC_ACTION_REPLACE := 1
const MUSIC_ACTION_DUCK := 2
const MUSIC_ACTION_RESTORE := 3

func _ready() -> void:
	input_pickable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not affect_on_enter:
		return
	if _has_fired and one_shot:
		return
	if not body.is_in_group(player_group):
		return
	_apply(false)

func _on_body_exited(body: Node) -> void:
	if not affect_on_exit:
		return
	if _has_fired and one_shot:
		return
	if not body.is_in_group(player_group):
		return
	_apply(true)

func _apply(is_exit: bool) -> void:
	if changes.size() > 0:
		for change in changes:
			_apply_change(change)
	else:
		if property_name == "":
			return
		for path in target_paths:
			var node := get_node_or_null(path)
			if node == null:
				continue
			if not _has_property(node, property_name):
				continue
			node.set(property_name, value)
	_play_sound()
	_apply_music(is_exit)
	_has_fired = true

func _play_sound() -> void:
	if sfx_stream == null:
		return
	var play := func() -> void:
		var player := AudioStreamPlayer2D.new()
		player.bus = "SFX"
		player.stream = sfx_stream
		player.volume_db = sfx_volume_db
		player.global_position = global_position if sfx_use_trigger_position else sfx_position
		player.finished.connect(player.queue_free)
		get_tree().current_scene.add_child(player)
		player.play()
	if sfx_delay > 0.0:
		get_tree().create_timer(sfx_delay).timeout.connect(play)
	else:
		play.call()

func _apply_music(is_exit: bool) -> void:
	if not music_enabled:
		return
	if MusicManager == null:
		return
	var action: int = music_on_exit if is_exit else music_on_enter
	match action:
		MUSIC_ACTION_REPLACE:
			MusicManager.play_music(music_stream, music_fade_time, music_volume_db)
		MUSIC_ACTION_DUCK:
			MusicManager.duck_music(music_fade_time)
		MUSIC_ACTION_RESTORE:
			MusicManager.restore_music_volume(music_fade_time)
		_:
			return

func _apply_change(change: PropertyChange) -> void:
	if change == null:
		return
	var target_path: NodePath = change.target
	var prop: String = change.property_name
	var val: Variant = change.value
	if target_path.is_empty() or prop == "":
		return
	var node := get_node_or_null(target_path)
	if node == null:
		return
	if not _has_property(node, prop):
		return
	node.set(prop, val)

func _has_property(node: Node, prop: String) -> bool:
	for info in node.get_property_list():
		if info.name == prop:
			return true
	return false
