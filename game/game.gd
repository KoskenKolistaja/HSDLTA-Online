extends Node3D


const PlayerScene: PackedScene = preload("res://Entities/player.tscn")

# TODO load the levels dynamically, not a problem with one level but with many takes up memory
var level_scenes: Dictionary[String, String] = {
	"TestLevel" = "res://game/levels/test_level.tscn" 
}
var current_level: BaseLevel = null


func _ready() -> void:
	# TODO spotty logic just for now... come up with something cleaner
	
	var args = OS.get_cmdline_args()
	if "--debug_players" in args and Net.is_server:
		var i := args.find("--debug_players")
		var num: int = int(args[i + 1])
		if num == 1:
			# The required debug players is one to start the game so do it immediately
			start_loading_level(level_scenes.keys().pick_random()) # Start loading random level
		Net.player_joined.connect(func(pd: PlayerData):
			# Auto-start when the required number of players have joined 
			# This is meant for debug joining using multiple run instances from godot Debug tab
			if Net.get_player_count() == num:
				push_warning("Debug host player count req met. Loading level...")
				start_loading_level(level_scenes.keys().pick_random()) # Start loading random level
		)
	elif Net.is_server:
		await get_tree().process_frame
		start_loading_level(level_scenes.keys().pick_random()) # Start loading random level


## Loads level for all clients
func start_loading_level(level_id: String) -> void:
	assert(Net.is_server)
	rpc_load_level.rpc(level_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_load_level(level_id: String) -> void:
	push_warning("Load level %s initiated by host" % level_id)
	var start_time := Time.get_ticks_msec()
	# Unload level
	if current_level:
		current_level.queue_free()
		current_level = null
	
	# Add level
	var level_packed_scene := load(level_scenes[level_id])
	var new_level: BaseLevel = level_packed_scene.instantiate()
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
	
	$LoadingScreen.hide()
