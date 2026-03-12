extends RefCounted
class_name CheckpointStateUtils

const CHECKPOINT_STATEFUL_GROUP := "checkpoint_stateful"

static func get_scene_relative_path(scene_root: Node, node: Node) -> String:
	if scene_root == null or node == null:
		return ""
	if node == scene_root:
		return "."
	if not scene_root.is_ancestor_of(node):
		return ""
	return str(scene_root.get_path_to(node))

static func capture_node_snapshot(node: Node) -> Dictionary:
	if node == null:
		return {}
	var snapshot: Dictionary = {}
	if node is Node2D:
		var node_2d := node as Node2D
		snapshot["global_position"] = node_2d.global_position
		snapshot["rotation"] = node_2d.rotation
		snapshot["scale"] = node_2d.scale
	if node is CanvasItem:
		snapshot["visible"] = (node as CanvasItem).visible
	if node is CharacterBody2D:
		snapshot["velocity"] = (node as CharacterBody2D).velocity
	if node is Area2D:
		var area := node as Area2D
		snapshot["monitoring"] = area.monitoring
		snapshot["monitorable"] = area.monitorable
	if node.has_method("capture_checkpoint_state"):
		var custom_state: Variant = node.call("capture_checkpoint_state")
		if custom_state is Dictionary:
			snapshot["custom"] = custom_state
	return snapshot

static func apply_node_snapshot(node: Node, snapshot: Dictionary) -> void:
	if node == null or snapshot.is_empty():
		return
	if node is Node2D:
		var node_2d := node as Node2D
		if snapshot.has("global_position"):
			node_2d.global_position = snapshot["global_position"]
		if snapshot.has("rotation"):
			node_2d.rotation = float(snapshot["rotation"])
		if snapshot.has("scale"):
			node_2d.scale = snapshot["scale"]
	if node is CanvasItem and snapshot.has("visible"):
		(node as CanvasItem).visible = bool(snapshot["visible"])
	if node is CharacterBody2D and snapshot.has("velocity"):
		(node as CharacterBody2D).velocity = snapshot["velocity"]
	if node is Area2D:
		var area := node as Area2D
		if snapshot.has("monitoring"):
			area.monitoring = bool(snapshot["monitoring"])
		if snapshot.has("monitorable"):
			area.monitorable = bool(snapshot["monitorable"])
	if node.has_method("apply_checkpoint_state"):
		var custom_state: Variant = snapshot.get("custom", {})
		if custom_state is Dictionary:
			node.call("apply_checkpoint_state", custom_state)

static func remove_absent_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.call_deferred("queue_free")
