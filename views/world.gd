extends Node3D

@onready var player = $Player

var current_time = 0

#func _physics_process(delta):
	#
	#if not current_time + 300 > Time.get_ticks_msec():
		#get_tree().call_group("enemy","update_target_location",player.global_transform.origin)
		#current_time = Time.get_ticks_msec()
