extends Node


@onready var player: Player = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		player.look_input += event.relative


func _physics_process(delta: float) -> void:
	player.jump_input = Input.is_action_just_pressed("ui_accept")
	player.move_input = Input.get_vector("left", "right", "up", "down")
