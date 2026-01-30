extends Node

@export var search_spots: Array[NodePath] = []

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("search_key_manager")
	_rng.randomize()
	_assign_key_to_random_spot()

func mark_all_spots_searched_empty() -> void:
	if search_spots.is_empty():
		return
	for path in search_spots:
		if path.is_empty():
			continue
		var spot := get_node_or_null(path)
		if spot == null:
			continue
		if spot.has_method("set_has_key"):
			spot.set_has_key(false)
		if spot.has_method("set_searched_empty"):
			spot.set_searched_empty(true)

func _assign_key_to_random_spot() -> void:
	if search_spots.is_empty():
		return

	var resolved: Array[Node] = []
	for path in search_spots:
		if path.is_empty():
			continue
		var spot := get_node_or_null(path)
		if spot == null:
			continue
		if spot.has_method("set_has_key"):
			spot.set_has_key(false)
			resolved.append(spot)

	if resolved.is_empty():
		return

	var selected := resolved[_rng.randi_range(0, resolved.size() - 1)]
	selected.set_has_key(true)
