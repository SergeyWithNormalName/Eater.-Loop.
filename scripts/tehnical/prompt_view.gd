extends Control

@export var text_node_path: NodePath = NodePath("Label")

var _text_node: Node

func _ready() -> void:
	_cache_text_node()

func set_prompt_text(text: String) -> void:
	if _text_node == null or not is_instance_valid(_text_node):
		_cache_text_node()
	if _text_node == null:
		return
	if _text_node.has_method("set_text"):
		_text_node.call("set_text", text)
	else:
		_text_node.set("text", text)

func _cache_text_node() -> void:
	if text_node_path.is_empty():
		_text_node = null
		return
	_text_node = get_node_or_null(text_node_path)
