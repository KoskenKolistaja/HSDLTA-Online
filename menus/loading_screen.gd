extends Control


func _process(delta: float) -> void:
	$TextureRect.rotation += delta
