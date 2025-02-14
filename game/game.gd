extends Node3D


signal level_load_finished(succesful: bool)

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
var currently_loading_level_path = ""
var current_level: BaseLevel = null



func _ready() -> void:
	transition_to(STATE.IN_LOBBY)
	var args = OS.get_cmdline_args()
	if "--debug_host" in args and Net.is_server:
		_debug_host_logic()
	
	lobby_screen.game_started.connect(func():
		host_initiate_level_load(level_scenes.keys().pick_random()) # Start loading random level
	)


func _process(delta: float) -> void:
	# Poll threaded level load to see if it's completed
	if state == STATE.LOADING_LEVEL and currently_loading_level_path != "":
		var load_state := ResourceLoader.load_threaded_get_status(currently_loading_level_path)
		if load_state == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			# Succesfully loaded
			currently_loading_level_path = ""
			level_load_finished.emit(true)
		elif load_state == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
			# Something went wrong while trying to load resource
			currently_loading_level_path = ""
			level_load_finished.emit(false)
		


func _debug_host_logic() -> void:
	var args = OS.get_cmdline_args()
	if "--autostart" in args:
		var i := args.find("--autostart")
		var num: int = int(args[i + 1])
		if num == 1:
			# The required debug players is one to start the game so do it immediately
			host_initiate_level_load(level_scenes.keys().pick_random()) # Start loading random level
		Net.player_joined.connect(func(pd: PlayerData):
			# Auto-start when the required number of players have joined 
			# This is meant for debug joining using multiple run instances from godot Debug tab
			if Net.get_player_count() == num:
				push_warning("Debug host player count req met. Loading level...")
				host_initiate_level_load(level_scenes.keys().pick_random()) # Start loading random level
		)


func transition_to(new_state: STATE) -> void:
	var old_state := state
	state = new_state
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
func host_initiate_level_load(level_id: String) -> void:
	assert(Net.is_server)
	rpc_open_level.rpc(level_id)


@rpc("any_peer", "call_local", "reliable")
func rpc_open_level(level_id: String) -> void:
	push_warning("Load level %s initiated by host" % level_id)
	transition_to(STATE.LOADING_LEVEL)
	var clock := Clock.new().start()
	# Unload level
	if current_level:
		current_level.queue_free()
		current_level = null
		print("Previous level free queued in %s" % clock.measure_and_restart())
	
	# Load level
	currently_loading_level_path = level_scenes[level_id]
	var level_packed_scene: PackedScene
	var err := ResourceLoader.load_threaded_request(level_scenes[level_id])
	print("Threaded load request filed in %sms" % clock.measure_and_restart())
	if err == OK:
		var c2 := Clock.new().start()
		var success: bool = await level_load_finished # Await the result
		print("\tAwait took %sms" % c2.measure_and_restart())
		if not success:
			level_packed_scene = load(level_scenes[level_id])
		level_packed_scene = ResourceLoader.load_threaded_get(level_scenes[level_id])
		print("\tResourceLoader.load_threaded_get took %s" % c2.measure())
	else:
		# For some reason threaded load is impossible, fall back to regular load
		push_error("Main thread level load fallback triggered")
		level_packed_scene = load(level_scenes[level_id])
	print("New level loaded in: %sms" % clock.measure_and_restart())
	
	# Add level
	var new_level: BaseLevel = level_packed_scene.instantiate()
	current_level = new_level
	add_child(new_level) # Currently this blocks the main thread, not sure how to avoid
	print("New level added in: %sms" % clock.measure_and_restart())
	
	new_level.level_completed.connect(func():
		if Net.is_server:
			host_initiate_level_load(level_scenes.keys().pick_random())
	)
	
	
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
	print("Players loaded in: %sms" % clock.measure_and_restart())
	
	# Process enemies
	for enemy in current_level.get_enemies():
		# Here some of the enemies can be deleted if wanted...
		# E.g. enemies could have a "difficulty" export var 
		# and ones with difficulty higher than current difficulty
		# are freed?
		pass
	transition_to(STATE.IN_GAME)
	print("Enemies updated in: %sms" % clock.measure_and_restart())
