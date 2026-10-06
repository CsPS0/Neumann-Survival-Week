extends Node

func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		get_viewport().scaling_3d_scale = 0.75
		RenderingServer.directional_shadow_atlas_set_size(1024, true)
		
		# Set up dynamic light distance culling and shadow tiers
		get_tree().node_added.connect(_on_node_added)
		_apply_to_existing_nodes(get_tree().root)

func _apply_to_existing_nodes(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_apply_to_existing_nodes(child)

func _on_node_added(node: Node) -> void:
	if node is OmniLight3D or node is SpotLight3D:
		node.distance_fade_enabled = true
		node.distance_fade_begin = 15.0
		node.distance_fade_shadow = 10.0
		node.distance_fade_length = 5.0
		# Limit shadows
		if node.shadow_enabled:
			# If we want we could disable shadows for distant lights or all but directional
			pass
