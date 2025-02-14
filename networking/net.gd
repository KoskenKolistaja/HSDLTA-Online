extends Node


signal player_joined(player_data: PlayerData)
signal player_left(player_data: PlayerData)

var is_server: bool = false
var _player_data: Dictionary[int, PlayerData] = {}


func _ready() -> void:
	# This is just for deving, should be replaced with proper joining etc. multiplayer stuff
	var args = OS.get_cmdline_args()
	is_server = "--debug_host" in args
	if is_server:
		host_game()
	elif "--debug_join" in args:
		# client
		start_joining_game("127.0.0.1")


func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(25565)
	multiplayer.multiplayer_peer = peer
	_create_player_for(multiplayer.multiplayer_peer.get_unique_id())
	push_warning("Hosted game")
	multiplayer.peer_connected.connect(func(network_id: int):
		push_warning("Peer connected, creating data...")
		for pd in _player_data.values():
			rpc_upsert_player.rpc_id(network_id, inst_to_dict(pd))
		_create_player_for(network_id)
	)


func start_joining_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip, 25565)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func():
		push_warning("Connected to host succesfully")
	)
	multiplayer.connection_failed.connect(func():
		push_error("Failed to connect to host")
	)
	multiplayer.server_disconnected.connect(func():
		push_error("Host disconnected")
		multiplayer.multiplayer_peer = null
		get_tree().change_scene_to_file("uid://bh2soybldlfol")
		# TODO Display msg that server disconnected
	)


func get_player_by_id(player_id: int) -> PlayerData:
	#print("getting player by id %s" % player_id)
	#print("_player_data: %s" % _player_data)
	for p in _player_data.values():
		if p.player_id == player_id:
			return p
	return null


func get_local_player() -> PlayerData:
	var i := _player_data.values().find_custom(func(pd: PlayerData): return pd.network_id == multiplayer.get_unique_id())
	assert(i != -1, "Could not find local player.")
	return _player_data.values()[i]


func get_local_player_or_null() -> PlayerData:
	#var i := _player_data.values().find_custom(func(pd: PlayerData): return pd.network_id == multiplayer.get_unique_id())
	return _player_data.get(multiplayer.get_unique_id(), null)
	#return _player_data.values()[i] if i != -1 else null


func get_player_by_net_id(network_id: int) -> PlayerData:
	return _player_data.get(network_id)


func get_player_count() -> int:
	push_warning("Player count: %s" % _player_data.size())
	return _player_data.size()


func get_players() -> Array[PlayerData]:
	return _player_data.values()


## Adds the player to _data (for all players) and returns the PlayerData
func _create_player_for(network_id: int) -> PlayerData:
	assert(is_server)
	var p := PlayerData.new()
	p.player_id = _player_data.size() + 1
	p.network_id = network_id
	p.name = "Player %s" % p.player_id
	rpc_upsert_player.rpc(inst_to_dict(p))
	return p


## Called by the hosting player on all players (including itself) to add player to player data
@rpc("any_peer", "call_local", "reliable")
func rpc_upsert_player(data: Dictionary) -> void:
	var player_data: PlayerData = dict_to_inst(data)
	push_warning("rpc_upsert_player rpc received: %s" % player_data)
	_add_player_data(player_data)


func _add_player_data(pd: PlayerData) -> void:
	_player_data[pd.network_id] = pd
	player_joined.emit(pd)


func _erase_player_data(pd: PlayerData) -> void:
	_player_data.erase(pd.player_id)
	player_left.emit(pd)
