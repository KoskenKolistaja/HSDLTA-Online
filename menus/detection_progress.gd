extends Control


func set_detection_level(level: float) -> void:
	$ProgressBar.value = level
	$Sprite2D.modulate = Color(1., 1., 1., ease(level, 0.6))
