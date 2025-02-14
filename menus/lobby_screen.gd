extends Control

signal game_started

const PlayerLobbyComponentScene := preload("res://menus/player_lobby_component.tscn")
const PlayerLobbyComponent := preload("res://menus/player_lobby_component.gd")

var _plcs: Dictionary[int, PlayerLobbyComponent] = {} ## player_id: PlayerLobbyComponent


func _ready() -> void:
	%StartButton.disabled = not Net.is_server
	%StartButton.pressed.connect(func(): game_started.emit())
	
	for pd in Net.get_players():
		var plc: PlayerLobbyComponent = PlayerLobbyComponentScene.instantiate()
		_plcs[pd.player_id] = plc
		plc.player_id = pd.player_id
		%PlayerContainer.add_child(plc, true)
	
	Net.player_joined.connect(func(pd: PlayerData):
		var plc: PlayerLobbyComponent = PlayerLobbyComponentScene.instantiate()
		_plcs[pd.player_id] = plc
		plc.player_id = pd.player_id
		%PlayerContainer.add_child(plc, true)
	)
	Net.player_left.connect(func(pd: PlayerData):
		var plc := _plcs[pd.player_id]
		plc.queue_free()
		_plcs.erase(pd.player_id)
	)
