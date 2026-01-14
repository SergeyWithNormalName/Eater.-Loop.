extends Area2D

@export_group("Minigame")
## Сцена мини-игры.
@export var minigame_scene: PackedScene
## Сцена еды (для мини-игры).
@export var food_scene: PackedScene
## Текстура лица Андрея.
@export var andrey_face: Texture2D
## Количество еды в мини-игре.
@export var food_count: int = 5
## Фоновая музыка мини-игры.
@export var bg_music: AudioStream
## Звук победы.
@export var win_sound: AudioStream
## Звук поедания.
@export var eat_sound: AudioStream
## Текстура фона мини-игры.
@export var background_texture: Texture2D

@export_group("Access")
## Требовать завершения лабораторной работы.
@export var require_lab_completion: bool = false
## ID требуемой лабораторной.
@export var required_lab_id: String = ""
## Сообщение, если доступ закрыт.
@export_multiline var locked_message: String = "Точно! Сначала я должен доделать лабораторную работу"
## Требовать ввод кода доступа.
@export var require_access_code: bool = false
## Код доступа.
@export var access_code: String = "1234"

@export_group("Teleport")
## Включить телепорт после взаимодействия.
@export var enable_teleport: bool = false
## Маркер телепорта.
@export var teleport_target: NodePath

@export_group("Sounds")
## Звук открытия холодильника.
@export var open_sound: AudioStream # Сюда перетащите звук открытия двери

@export_group("Visuals")
## Текстура холодильника, когда он недоступен.
@export var locked_sprite: Texture2D
## Текстура холодильника, когда он доступен.
@export var available_sprite: Texture2D
## Узел со спрайтом холодильника.
@export var sprite_node: NodePath = NodePath("Sprite2D")
## Узел подсветки доступности (основной).
@export var available_light_node: NodePath
## Узел подсветки доступности (дополнительный).
@export var available_light_node_secondary: NodePath

var player_inside: bool = false
var _is_interacting: bool = false
var _current_minigame: Node = null
var _sfx_player: AudioStreamPlayer
var _code_unlocked: bool = false
var _code_canvas: CanvasLayer = null
var _sprite: Sprite2D = null
var _available_light: CanvasItem = null
var _available_light_secondary: CanvasItem = null

func _ready() -> void:
	input_pickable = false
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)
	
	_sprite = get_node_or_null(sprite_node) as Sprite2D
	_available_light = get_node_or_null(available_light_node) as CanvasItem
	_available_light_secondary = get_node_or_null(available_light_node_secondary) as CanvasItem
	_update_visuals()
	if GameState.has_signal("lab_completed"):
		GameState.lab_completed.connect(func(_id): _update_visuals())

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		if InteractionPrompts:
			InteractionPrompts.show_interact(self)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		if InteractionPrompts:
			InteractionPrompts.hide_interact(self)

func _unhandled_input(event: InputEvent) -> void:
	if _is_interacting:
		return
	if not player_inside:
		return
	
	if event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	if GameState.has_method("mark_fridge_interacted"):
		GameState.mark_fridge_interacted()

	if GameState.ate_this_cycle:
		UIMessage.show_text("Я уже поел.")
		return

	if _is_locked_by_lab():
		UIMessage.show_text(locked_message)
		return
	if _is_locked_by_code():
		_open_code_lock()
		return
	
	_is_interacting = true
	_set_prompts_enabled(false)
	
	if open_sound:
		_sfx_player.stream = open_sound
		_sfx_player.play()
	
	if minigame_scene == null or food_scene == null:
		push_warning("Frizzer: Minigame scene or Food scene is missing!")
		_complete_feeding()
		_is_interacting = false
		_set_prompts_enabled(true)
		return
	
	await UIMessage.fade_out(0.3)
	_start_minigame()
	await UIMessage.fade_in(0.3)

func _start_minigame() -> void:
	var game = minigame_scene.instantiate()
	_current_minigame = game
	get_tree().root.add_child(game)
	
	if game.has_method("setup_game"):
		game.setup_game(andrey_face, food_scene, food_count, bg_music, win_sound, eat_sound, background_texture)
	
	game.minigame_finished.connect(_on_minigame_finished)

func _on_minigame_finished() -> void:
	await UIMessage.fade_out(0.4)
	
	if _current_minigame != null:
		_current_minigame.queue_free()
		_current_minigame = null
	
	_complete_feeding()
	_teleport_player_if_needed()
	
	await UIMessage.fade_in(0.4)
	_is_interacting = false
	_set_prompts_enabled(true)

func _complete_feeding() -> void:
	GameState.mark_ate()
	UIMessage.show_text("Вкуснятина")
	
	var current_level = get_tree().current_scene
	if current_level.has_method("on_fed_andrey"):
		current_level.on_fed_andrey()

func _is_locked_by_lab() -> bool:
	if not require_lab_completion:
		return false
	if required_lab_id == "":
		return true
	return not GameState.completed_labs.has(required_lab_id)

func _is_locked_by_code() -> bool:
	return require_access_code and not _code_unlocked

func _update_visuals() -> void:
	var is_available := not _is_locked_by_lab() and not _is_locked_by_code()
	if is_available:
		if _sprite and available_sprite:
			_sprite.texture = available_sprite
		if _available_light:
			_available_light.visible = true
		if _available_light_secondary:
			_available_light_secondary.visible = true
	else:
		if _sprite and locked_sprite:
			_sprite.texture = locked_sprite
		if _available_light:
			_available_light.visible = false
		if _available_light_secondary:
			_available_light_secondary.visible = false

func _open_code_lock() -> void:
	if _is_interacting:
		return
	_is_interacting = true
	_set_prompts_enabled(false)
	
	var code_scene := load("res://scenes/minigames/ui/code_lock.tscn") as PackedScene
	if code_scene == null:
		push_warning("Frizzer: code_lock.tscn не найден.")
		_is_interacting = false
		_set_prompts_enabled(true)
		return
	
	var lock = code_scene.instantiate()
	lock.code_value = access_code
	lock.unlocked.connect(_on_code_unlocked)
	lock.tree_exited.connect(_on_code_closed)
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(lock)
	get_tree().root.add_child(canvas)
	_code_canvas = canvas

func _on_code_unlocked() -> void:
	_code_unlocked = true
	UIMessage.show_text("Замок открыт.")
	_update_visuals()

func _on_code_closed() -> void:
	_is_interacting = false
	_set_prompts_enabled(true)
	if _code_canvas != null:
		_code_canvas.queue_free()
		_code_canvas = null

func _teleport_player_if_needed() -> void:
	if not enable_teleport:
		return
	if teleport_target.is_empty():
		push_warning("Frizzer: teleport_target не задан.")
		return
	
	var marker := get_node_or_null(teleport_target)
	if marker == null:
		push_warning("Frizzer: teleport_target не найден.")
		return
	
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(false)
	if player:
		player.global_position = marker.global_position
	await get_tree().create_timer(0.1).timeout
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(true)

func _set_prompts_enabled(enabled: bool) -> void:
	if InteractionPrompts == null:
		return
	if InteractionPrompts.has_method("set_prompts_enabled"):
		InteractionPrompts.set_prompts_enabled(enabled)
	elif enabled:
		if player_inside:
			InteractionPrompts.show_interact(self)
	else:
		InteractionPrompts.hide_interact(self)
