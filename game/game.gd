extends Node3D


enum STATE {
	IN_LOBBY,
	LOADING_LEVEL,
	IN_GAME,
}

const PlayerScene: PackedScene = preload("res://Entities/player.tscn")

@onready var loading_screen := $LoadingScreen
@onready var lobby_screen := $LobbyScreen

var state: STATE = STATE.IN_LOBBY
var level_scenes: Dictionary[String, String] = {
	"TestLevel" = "res://game/levels/test_level.tscn" 
}
var current_level: BaseLevel = null



func _ready() -> void:
	transition_to(STATE.IN_LOBBY)
	var args = OS.get_cmdline_args()
	if "--debug_host" in args and Net.is_server:
		_debug_host_logic()
	
	lobby_screen.game_started.connect(func():
		start_loading_level(level_scenes.keys().pick_random()) # Start loading random level
	)


func _debug_host_logic() -> void:
	var args = OS.get_cmdline_args()
	if "--autostart" in args:
		var i := args.find("--autostart")
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


func transition_to(new_state: STATE) -> void:
	var old_state := state
	match new_state:
		STATE.IN_LOBBY:
			if current_level:
				current_level.hide()
			loading_screen.hide()
			lobby_screen.show()
		STATE.LOADING_LEVEL:
			if current_level:
				current_level.hide()
			lobby_screen.hide()
			loading_screen.show()
		STATE.IN_GAME:
			lobby_screen.hide()
			loading_screen.hide()
			if current_level:
				current_level.show() # probs not necessary?


## Loads level for all clients. Should only be called by host
func start_loading_level(level_id: String) -> void:
	assert(Net.is_server)
	rpc_load_level.rpc(level_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_load_level(level_id: String) -> void:
	push_warning("Load level %s initiated by host" % level_id)
	transition_to(STATE.LOADING_LEVEL)
	var start_time := Time.get_ticks_msec()
	# Unload level
	if current_level:
		current_level.queue_free()
		current_level = null
	
	# Add level
	# TODO load level in another thread...
	var level_packed_scene := load(level_scenes[level_id])
	var new_level: BaseLevel = level_packed_scene.instantiate()
	current_level = new_level
	add_child(new_level)
	
	new_level.level_completed.connect(func():
		if Net.is_server:
			start_loading_level(level_scenes.keys().pick_random())
	)
	
	var add_time := Time.get_ticks_msec() - start_time
	print("Instantiated level in: %sms" % add_time)
	
	# Load players
	var spawns := current_level.get_player_spawn_locations()
	for i in spawns.size():
		i += 1 # To match player ids which start from 1
		var pd := Net.get_player_by_id(i)
		if not pd:
			# Skip if player doesn't exist
			continue
		var spawn := spawns[i]
		var p: Player = PlayerScene.instantiate()
		p.player_id = i
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
	transition_to(STATE.IN_GAME)
