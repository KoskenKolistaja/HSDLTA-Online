extends Node


@onready var player: Player = get_parent()


func _ready() -> void:
	if not player.is_local:
		queue_free()
	Input.set_use_accumulated_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		player.look_input += event.relative


func _physics_process(delta: float) -> void:
	player.jump_input = Input.is_action_just_pressed("ui_accept")
	player.move_input = Input.get_vector("left", "right", "up", "down")
	player.sprint_input = Input.is_action_pressed("sprint")
	player.crouch_input = Input.is_action_pressed("crouch")
	player.started_shooting_input = Input.is_action_just_pressed("mouse1")
	player.shooting_input = Input.is_action_pressed("mouse1")
