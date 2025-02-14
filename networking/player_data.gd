extends RefCounted
class_name PlayerData


var name: String
var player_id: int
var network_id: int


func _to_string() -> String:
	return "%s, player_id: %s, network_id: %s" % [name, player_id, network_id]


func is_local() -> bool:
	return Net.get_local_player_or_null().player_id == player_id
