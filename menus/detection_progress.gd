extends Control


func set_detection_level(level: float) -> void:
	$ProgressBar.value = level
	$Sprite2D.modulate = Color(1., 1., 1., max(level, 0.5))
	$Sprite2D/ColorRect.scale.x = level
