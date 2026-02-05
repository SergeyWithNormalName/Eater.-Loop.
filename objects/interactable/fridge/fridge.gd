extends InteractiveObject


@export_group("Minigame (Feeding)")
## Сцена мини-игры (еда).
@export var minigame_scene: PackedScene
## Набор сцен еды.
@export var food_scenes: Array[PackedScene] = []
## Текстура лица Андрея.
@export var andrey_face: Texture2D
## Количество еды.
@export var food_count: int = 5
## Музыка и звуки.
@export var bg_music: AudioStream
@export var win_sound: AudioStream
@export var eat_sound: AudioStream
@export var background_texture: Texture2D

@export_group("Security")
## Требовать ввод кода доступа.
@export var require_access_code: bool = false
## Код доступа.
@export var access_code: String = "1234"
## Сообщение, если код не введен или неверный.
@export var access_code_failed_message: String = ""
## Сцена мини-игры "Кодовый замок".
@export var code_lock_scene: PackedScene 

@export_group("Lab Requirement")
## Запретить еду, пока не сдана лабораторная.
@export var require_lab_completion: bool = false
## Сообщение, если лабораторная еще не выполнена.
@export var lab_required_message: String = "Сначала нужно сделать лабораторную работу."

@export_group("Teleport")
@export var enable_teleport: bool = false
@export var teleport_target: NodePath

@export_group("Visuals & Audio")
@export var open_sound: AudioStream 
## Фоновый шум холодильника.
@export var noise_sound: AudioStream
## Громкость шума холодильника (dB).
@export var noise_volume_db: float = -18.0
## Узел проигрывателя шума.
@export var noise_player_node: NodePath = NodePath("AudioStreamPlayer2D")
@export var locked_sprite: Texture2D
@export var available_sprite: Texture2D
@export var sprite_node: NodePath = NodePath("Sprite2D")
@export var available_light_node: NodePath
@export var available_light_node_secondary: NodePath

@export_group("Idle Rocking")
## Длительность одного полного цикла (сек). Меньше = быстрее.
@export var rocking_cycle_duration: float = 2.0
## Сила покачивания в градусах.
@export var rocking_strength_degrees: float = 0.0
## Точка подвеса: 0 = по центру (обычные холодильники), 1 = подвес сверху.
@export_enum("Centered", "Hanging") var rocking_pivot_mode: int = 0
## Доп. смещение точки подвеса (пиксели, до масштаба).
@export var rocking_pivot_offset: Vector2 = Vector2.ZERO
## Звук покачивания.
@export var rocking_sound: AudioStream

# Внутренние переменные
var _is_interacting: bool = false
var _current_minigame: Node = null
var _sfx_player: AudioStreamPlayer
var _code_unlocked: bool = false # Флаг, открыт ли замок
var _sprite: Sprite2D = null
var _available_light: CanvasItem = null
var _available_light_secondary: CanvasItem = null
var _noise_player: AudioStreamPlayer2D = null
var _rocking_active: bool = false
var _rocking_elapsed: float = 0.0
var _rocking_base_rotation: float = 0.0
var _rocking_sound_player: AudioStreamPlayer2D = null
var _rocking_sound_connected: bool = false

func _ready() -> void:
	super._ready() # Важно вызвать ready родителя!
	set_process(false)
	
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Sounds"
	add_child(_sfx_player)
	
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	_available_light = get_node_or_null(available_light_node) as CanvasItem
	_available_light_secondary = get_node_or_null(available_light_node_secondary) as CanvasItem
	_noise_player = get_node_or_null(noise_player_node) as AudioStreamPlayer2D
	if _noise_player:
		if noise_sound:
			_noise_player.stream = noise_sound
		_noise_player.volume_db = noise_volume_db
	
	_update_visuals()
	_update_rocking_pivot()
	_start_rocking_if_configured()
	
	if require_lab_completion and GameState.has_signal("lab_completed"):
		GameState.lab_completed.connect(_update_visuals)

# --- ОСНОВНАЯ ТОЧКА ВХОДА ---
func _on_interact() -> void:
	if _is_interacting:
		return

	# 0. Проверка: лабораторная не завершена
	if require_lab_completion and not GameState.lab_done:
		_show_locked_message()
		return

	# 1. Проверка: уже ел?
	if GameState.ate_this_cycle:
		UIMessage.show_text("Я уже поел.")
		return
	
	# 2. Проверка: погоня?
	if _is_chase_active():
		UIMessage.show_text("Нельзя есть на бегу!")
		return

	# 3. Если замок закрыт — запускаем взлом
	if require_access_code and not _code_unlocked:
		_start_code_lock()
		return

	# 4. Если всё ок (замок открыт или не нужен) — ЕДИМ
	_start_feeding_process()

# --- ЛОГИКА КОДОВОГО ЗАМКА ---
func _start_code_lock() -> void:
	if code_lock_scene == null:
		push_warning("Frizzer: Не назначена сцена Code Lock!")
		return
	
	# 1. Создаем экземпляр (Node) из PackedScene
	var lock_instance = code_lock_scene.instantiate()
	_current_minigame = lock_instance
	
	# 2. Настраиваем пароль (как в твоем старом скрипте)
	if "code_value" in lock_instance:
		lock_instance.code_value = access_code
	elif "target_code" in lock_instance:
		lock_instance.target_code = access_code
	
	# 3. Подключаем сигнал успеха
	if lock_instance.has_signal("unlocked"):
		lock_instance.unlocked.connect(_on_unlock_success)
	
	# Добавляем обработку закрытия (чтобы разблокировать игрока, если он нажал отмену)
	lock_instance.tree_exited.connect(func():
		_is_interacting = false
		if require_access_code and not _code_unlocked:
			_show_access_code_failed_message()
	)

	# 4. Добавляем замок на сцену (поверх всего, но внутри текущей сцены)
	_add_minigame_to_scene(lock_instance)
	
	# 5. Теперь передаем ГОТОВЫЙ NODE в контроллер
	if MinigameController:
		_is_interacting = true
		var settings := MinigameSettings.new()
		settings.pause_game = false
		settings.enable_gamepad_cursor = true
		settings.block_player_movement = true
		settings.allow_pause_menu = false
		settings.allow_cancel_action = true
		MinigameController.start_minigame(lock_instance, settings)
	else:
		push_error("MinigameController не найден!")

func _on_unlock_success() -> void:
	_code_unlocked = true
	_is_interacting = false
	UIMessage.show_text("Замок открыт.")
	_update_visuals()
	
	# Сразу после взлома можно предложить поесть или заставить нажать Е еще раз.
	# Давай заставим нажать Е еще раз, чтобы игрок увидел открытую дверь.

func _on_unlock_cancel() -> void:
	_is_interacting = false

# --- ЛОГИКА ЕДЫ ---
func _start_feeding_process() -> void:
	_is_interacting = true
	
	# Звук открытия
	if open_sound:
		_sfx_player.stream = open_sound
		_sfx_player.play()
	
	# Проверка наличия еды
	var has_food := not food_scenes.is_empty()
	if minigame_scene == null or not has_food:
		push_warning("Frizzer: Нет сцены мини-игры или еды!")
		_finish_feeding_logic()
		return
	
	# Запуск игры
	await UIMessage.fade_out(0.3)
	
	var game = minigame_scene.instantiate()
	_current_minigame = game
	_add_minigame_to_scene(game)
	
	# Передаем параметры (как в твоем старом скрипте)
	if game.has_method("setup_game"):
		game.setup_game(andrey_face, food_count, bg_music, win_sound, eat_sound, background_texture, food_scenes)
	
	game.minigame_finished.connect(_on_feeding_finished)
	await UIMessage.fade_in(0.3)

func _on_feeding_finished() -> void:
	await UIMessage.fade_out(0.4)
	
	if _current_minigame != null:
		_current_minigame.queue_free()
		_current_minigame = null
	
	_finish_feeding_logic()
	
	await UIMessage.fade_in(0.4)
	_is_interacting = false

func _finish_feeding_logic() -> void:
	GameState.mark_ate()
	UIMessage.show_text("Вкуснятина")
	
	if GameState.has_method("mark_fridge_interacted"):
		GameState.mark_fridge_interacted()

	var current_level = get_tree().current_scene
	if current_level.has_method("on_fed_andrey"):
		current_level.on_fed_andrey()

	# ВАЖНО: Помечаем объект выполненным только ПОСЛЕ еды.
	# Теперь Ноутбук (зависящий от Холодильника) станет доступен.
	complete_interaction() 
	
	_teleport_player_if_needed()

func _show_locked_message() -> void:
	if require_lab_completion and not GameState.lab_done:
		if UIMessage and UIMessage.has_method("show_message"):
			UIMessage.show_message(lab_required_message)
		else:
			print("LOCKED: " + lab_required_message)
		return
	super._show_locked_message()

func _show_access_code_failed_message() -> void:
	var message := access_code_failed_message.strip_edges()
	if message == "":
		return
	if UIMessage and UIMessage.has_method("show_text"):
		UIMessage.show_text(message)

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
func _is_chase_active() -> bool:
	if MusicManager and MusicManager.has_method("is_chase_active"):
		return MusicManager.is_chase_active()
	return false

func _update_visuals() -> void:
	# Доступен, если не требуется код/лаба ИЛИ условия выполнены
	var is_unlocked := (not require_access_code or _code_unlocked)
	if require_lab_completion and not GameState.lab_done:
		is_unlocked = false
	
	if is_unlocked:
		if _sprite and available_sprite:
			_sprite.texture = available_sprite
		if _available_light: _available_light.visible = true
		if _available_light_secondary: _available_light_secondary.visible = true
	else:
		if _sprite and locked_sprite:
			_sprite.texture = locked_sprite
		if _available_light: _available_light.visible = false
		if _available_light_secondary: _available_light_secondary.visible = false
	_update_rocking_pivot()

func _teleport_player_if_needed() -> void:
	if not enable_teleport or teleport_target.is_empty():
		return
	var marker = get_node_or_null(teleport_target)
	if marker:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.global_position = marker.global_position

func _update_rocking_pivot() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	if rocking_pivot_mode == 1:
		var tex_size := _sprite.texture.get_size()
		# Поворот вокруг верхней кромки (эффект подвешенности).
		_sprite.centered = false
		_sprite.offset = Vector2(-tex_size.x * 0.5, 0.0) + rocking_pivot_offset
	else:
		# Стандартная центрированная отрисовка.
		_sprite.centered = true
		_sprite.offset = Vector2.ZERO

func _start_rocking_if_configured() -> void:
	if rocking_strength_degrees <= 0.0:
		return
	if _sprite == null:
		return
	if _rocking_active:
		return
	_rocking_active = true
	_rocking_elapsed = 0.0
	_rocking_base_rotation = _sprite.rotation
	if rocking_sound:
		if _rocking_sound_player == null:
			_rocking_sound_player = AudioStreamPlayer2D.new()
			_rocking_sound_player.bus = "Sounds"
			_rocking_sound_player.volume_db = -12.0
			add_child(_rocking_sound_player)
			_rocking_sound_connected = false
		_rocking_sound_player.stream = rocking_sound
		_rocking_sound_player.play()
		if not _rocking_sound_connected:
			_rocking_sound_player.finished.connect(_on_rocking_sound_finished)
			_rocking_sound_connected = true
	set_process(true)

func _process(delta: float) -> void:
	if not _rocking_active or _sprite == null:
		return
	_rocking_elapsed += delta
	var cycle: float = max(0.05, float(rocking_cycle_duration))
	var angle := sin(_rocking_elapsed * TAU / cycle) * deg_to_rad(rocking_strength_degrees)
	_sprite.rotation = _rocking_base_rotation + angle

func _stop_rocking() -> void:
	_rocking_active = false
	if _sprite:
		_sprite.rotation = _rocking_base_rotation
	if _rocking_sound_player:
		_rocking_sound_player.stop()
	set_process(false)

func _on_rocking_sound_finished() -> void:
	if _rocking_active and _rocking_sound_player:
		_rocking_sound_player.play()

func _add_minigame_to_scene(minigame: Node) -> void:
	if minigame == null:
		return
	if MinigameController and MinigameController.has_method("attach_minigame"):
		MinigameController.attach_minigame(minigame)
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if parent:
		parent.add_child(minigame)
