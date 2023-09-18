extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected()
signal test_player_conditions(players_remaining)
signal state_updated()

const PORT = 7000
const DEFAULT_IP = "127.0.0.1"
const MAX_CONNECTIONS = 10

var players = {}
var player_info = {
	"name": "Player",
	"cards": [],
	"chips": 200,
	"current_bet": 0
}
var game_state = {
	"pot": 0,
	"comm_cards": [],
	"active_players": [],
	"folded_players": [],
	"losers": []
}

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_IP
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error: return error
	multiplayer.multiplayer_peer = peer

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error: return error
	multiplayer.multiplayer_peer = peer
	
	players[1] = player_info
	player_connected.emit(1, player_info)
	test_player_conditions.emit(1)

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	test_player_conditions.emit(players.keys().size())

func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)
	test_player_conditions.emit(players.keys().size())

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_connected_fail():
	remove_multiplayer_peer()

func _on_server_disconnected():
	remove_multiplayer_peer()
	server_disconnected.emit()

func me():
	return players[multiplayer.get_unique_id()]

func get_live_players():
	return game_state["active_players"].size() - game_state["folded_players"].size()

@rpc("authority", "call_local", "reliable", 2)
func sync_data(player_data, state):
	Netgame.players = player_data
	Netgame.game_state = state
#	prints(multiplayer.get_unique_id(), "data received")
	state_updated.emit()