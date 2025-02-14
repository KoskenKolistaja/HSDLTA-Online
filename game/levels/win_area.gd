extends Area3D


func _ready() -> void:
	body_entered.connect(func(body: Node3D):
		if body is Player:
			get_parent().level_completed.emit()
	)
