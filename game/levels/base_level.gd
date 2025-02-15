extends Node3D
class_name BaseLevel

## Base class that all levels should inherit from (or just use as script)

signal level_completed
signal level_failed

var _clock


func _enter_tree() -> void:
	_clock = Clock.new()
	

func _ready() -> void:
	if _clock:
		push_warning("Level _ready() functions in %sms" % _clock.measure())
	else:
		push_error("BaseLevel _clock not found in _ready()")


func get_player_spawn_locations() -> Array[Node3D]:
	var arr: Array[Node3D] = []
	arr.assign(get_tree().get_nodes_in_group("player_spawn_position"))
	return arr


func get_enemies() -> Array[Node3D]:
	var arr: Array[Node3D] = []
	arr.assign(get_tree().get_nodes_in_group("enemy"))
	return arr
