extends RefCounted
class_name PlayerData


var name: String
var player_id: int
var network_id: int


func _to_string() -> String:
	return "%s, player_id: %s, network_id: %s" % [name, player_id, network_id]
