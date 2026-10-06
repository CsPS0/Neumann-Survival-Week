class_name ProximityVoice extends AudioStreamPlayer3D

func _ready() -> void:
	unit_size = 2.0
	max_distance = 25.0
	attenuation_filter_cutoff_hz = 5000.0
	# Setup voip stream if multiplayer peer is active
	if NetSession.is_multiplayer_active():
		var mic = AudioStreamMicrophone.new()
		stream = mic
		play()
