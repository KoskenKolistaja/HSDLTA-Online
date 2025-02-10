extends Node3D


const PlayerScene: PackedScene = preload("res://Entities/player.tscn")

# TODO load the levels dynamically, not a problem with one level but with many could be
var level_scenes: Dictionary[String, PackedScene] = {
	"TestLevel" = preload("res://game/levels/test_level.tscn") 
}
var current_level: BaseLevel = null


func _ready() -> void:
	# For deving, will be replaced later with proper logic
	start_loading_level(level_scenes.keys().pick_random()) # Start loading random level


## Loads level for all clients
func start_loading_level(level_id: String) -> void:
	assert(Net.is_server)
	rpc_load_level.rpc(level_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_load_level(level_id: String) -> void:
	var start_time := Time.get_ticks_msec()
	# Unload level
	if current_level:
		current_level.queue_free()
		current_level = null
	
	# Add level
	var new_level: BaseLevel = level_scenes[level_id].instantiate()
	current_level = new_level
	add_child(new_level)
	
	var add_time := Time.get_ticks_msec() - start_time
	print("Instantiated level in: %sms" % add_time)
	
	# Load players
	var spawns := current_level.get_player_spawn_locations()
	for i in spawns.size():
		if not Net.get_player_by_id(i):
			# Skip if player doesn't exist
			continue
		var spawn := spawns[i]
		var p: Player = PlayerScene.instantiate()
		p.position = spawn.position
		current_level.add_child(p)
	print("Loaded players in: %sms" % (Time.get_ticks_msec() - start_time - add_time))
	
	# Process enemies
	for enemy in current_level.get_enemies():
		# Here some of the enemies can be deleted if wanted...
		# E.g. enemies could have a "difficulty" export var 
		# and ones with difficulty higher than current difficulty
		# are freed?
		pass
