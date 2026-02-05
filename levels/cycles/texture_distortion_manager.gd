extends Node

@export_group("Texture Distortion")
@export var texture_map: Dictionary = {}
@export var scan_root: NodePath

@export_group("Distortion Music")
@export var distortion_music: AudioStream
@export_range(-80.0, 6.0, 0.1) var distortion_music_volume_db: float = -6.0
@export_range(0.0, 10.0, 0.1) var distortion_music_fade_time: float = 1.0

@export_group("Distortion SFX")
@export var distortion_sfx: AudioStream
@export_range(-80.0, 6.0, 0.1) var distortion_sfx_volume_db: float = 0.0

var _targets: Array[Dictionary] = []
var _texture_map_by_path: Dictionary = {}
var _sfx_player: AudioStreamPlayer
var _distortion_music_active: bool = false

func _ready() -> void:
	_build_texture_path_cache()
	_cache_targets()
	_setup_sfx_player()
	_connect_to_game_director()
	_connect_to_minigame_controller()
	if GameState and GameState.phase == GameState.Phase.DISTORTED:
		_on_distortion_started()

func _exit_tree() -> void:
	_stop_distortion_music()

func _build_texture_path_cache() -> void:
	_texture_map_by_path.clear()
	for key in texture_map.keys():
		if key is Texture2D and key.resource_path != "":
			_texture_map_by_path[key.resource_path] = texture_map[key]

func _cache_targets() -> void:
	_targets.clear()
	var root := _resolve_scan_root()
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Sprite2D:
			_try_register_sprite(node)
		for child in node.get_children():
			if child is Node:
				stack.append(child)

func _resolve_scan_root() -> Node:
	if scan_root != NodePath(""):
		return get_node_or_null(scan_root)
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene
	return get_parent()

func _try_register_sprite(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var replacement: Texture2D = null
	if texture_map.has(sprite.texture):
		replacement = texture_map[sprite.texture]
	else:
		var path := sprite.texture.resource_path
		if path != "" and _texture_map_by_path.has(path):
			replacement = _texture_map_by_path[path]
	if replacement == null:
		return
	_targets.append({"sprite": sprite, "texture": replacement})

func _setup_sfx_player() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Sounds"
	add_child(_sfx_player)

func _connect_to_game_director() -> void:
	var game_director := get_node_or_null("/root/GameDirector")
	if game_director == null:
		return
	if game_director.has_signal("distortion_started") and not game_director.distortion_started.is_connected(_on_distortion_started):
		game_director.distortion_started.connect(_on_distortion_started)

func _connect_to_minigame_controller() -> void:
	if MinigameController == null:
		return
	if MinigameController.has_signal("minigame_finished") and not MinigameController.minigame_finished.is_connected(_on_minigame_finished):
		MinigameController.minigame_finished.connect(_on_minigame_finished)

func _on_distortion_started() -> void:
	_apply_texture_distortion()
	_play_distortion_music()
	_play_distortion_sfx()

func _apply_texture_distortion() -> void:
	for entry in _targets:
		var sprite: Sprite2D = entry["sprite"]
		var replacement: Texture2D = entry["texture"]
		if sprite and replacement:
			sprite.texture = replacement

func _play_distortion_music() -> void:
	if distortion_music == null:
		return
	if MusicManager == null:
		return
	if _is_minigame_music_active():
		return
	if _distortion_music_active:
		return
	_distortion_music_active = true
	MusicManager.start_distortion_music(self, distortion_music, distortion_music_fade_time, distortion_music_volume_db)

func _on_minigame_finished(_minigame: Node, _success: bool) -> void:
	if GameState == null:
		return
	if GameState.phase != GameState.Phase.DISTORTED:
		return
	_play_distortion_music()

func _stop_distortion_music() -> void:
	if not _distortion_music_active:
		return
	if MusicManager == null:
		_distortion_music_active = false
		return
	MusicManager.stop_distortion_music(self, distortion_music_fade_time)
	_distortion_music_active = false

func _is_minigame_music_active() -> bool:
	if MinigameController == null:
		return false
	if MinigameController.has_method("should_block_player_movement"):
		return MinigameController.should_block_player_movement()
	return false

func _play_distortion_sfx() -> void:
	if distortion_sfx == null:
		return
	if _sfx_player == null:
		return
	_sfx_player.stream = distortion_sfx
	_sfx_player.volume_db = distortion_sfx_volume_db
	_sfx_player.play()
