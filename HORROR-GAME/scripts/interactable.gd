extends StaticBody3D
## Generic E-interactable (fuse box, safe, altar...). Solid; the world builder attaches the meshes.
## `prompt` is shown on the HUD while the player looks at it; `handler(player)` runs on E.

var prompt := "Use"
var handler: Callable


func interact(by: Node = null) -> void:
	if handler.is_valid():
		handler.call(by)
