extends Node

var xr_interface: XRInterface

func _ready() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR already initialized")
		get_viewport().use_xr = true
	elif xr_interface and xr_interface.initialize():
		print("OpenXR initialized successfully")
		# Important: set use_xr before rendering happens
		get_viewport().use_xr = true
	else:
		print("OpenXR not initialized, running in standard mode")

func is_xr_active() -> bool:
	return xr_interface != null and xr_interface.is_initialized()
