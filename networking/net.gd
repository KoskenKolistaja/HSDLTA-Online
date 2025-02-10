extends Node


var is_server: bool = false
var _player_data: Dictionary[int, PlayerData] = {}


func _ready() -> void:
	# This is just for deving, should be replaced with proper joining etc. multiplayer stuff
	is_server = true
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(25565)
	multiplayer.multiplayer_peer = peer
	_create_player_for(multiplayer.multiplayer_peer.get_unique_id())


## Adds the player to _data (for all players) and returns the PlayerData
func _create_player_for(network_id: int) -> PlayerData:
	assert(is_server)
	var p := PlayerData.new()
	p.player_id = _player_data.size() + 1
	p.name = "Player %s" % p.player_id
	rpc_upsert_player.rpc(inst_to_dict(p))
	return p


## Called by the hosting player on all players (including itself) to add player to player data
@rpc("any_peer", "call_local", "reliable")
func rpc_upsert_player(data: Dictionary) -> void:
	var player_data: PlayerData = dict_to_inst(data)
	_player_data[player_data.network_id] = player_data


func get_player_by_id(player_id: int) -> PlayerData:
	for p in _player_data.values():
		if p.player_id == player_id:
			return p
	return null


func get_player_by_net_id(network_id: int) -> PlayerData:
	return _player_data.get(network_id)
