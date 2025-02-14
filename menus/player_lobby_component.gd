extends HBoxContainer


var player_id: int
var player: PlayerData:
	get:
		return Net.get_player_by_id(player_id)


func _ready() -> void:
	assert(player_id)
	_update()


func _process(delta: float) -> void:
	# Game.tscn sets process_mode to false when not needed
	_update() 


func _update() -> void:
	$NameLabel.text = player.name
	
	if player.network_id == multiplayer.get_unique_id():
		$PingLabel.hide()
		return
	var peer := (multiplayer.multiplayer_peer as ENetMultiplayerPeer)
	var connection := peer.get_peer(player.network_id)
	if not connection:
		$PingLabel.text = "..."
	else:
		$PingLabel.text = "%.0fms" % connection.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
